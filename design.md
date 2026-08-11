# design.md — Arquitectura del motor de contenido (GnuCOBOL 3.x)

Este documento traduce [requirements.md](requirements.md) en una arquitectura concreta. Cada decisión de diseño referencia el/los REQ-ID que la motivan. No incluye implementación (PROCEDURE DIVISION, etc.); los ejemplos JSON son **contratos de interfaz**, no código COBOL.

Los "agentes" de este diseño son programas GnuCOBOL independientes, compilados como módulos separados y orquestados mediante `CALL` dinámico. El término "agente" se usa aquí en el sentido de *unidad de responsabilidad única dentro de un pipeline*, no de agente autónomo de IA — la única pieza que interactúa con un modelo de lenguaje es el `ContentAgent` (y, opcionalmente, `ImageAgent`), a través de un adaptador.

---

## 1. Diagrama de arquitectura (capas, agentes, dirección de dependencias)

```
                    ┌─────────────────────────────────────────────────┐
                    │         ADAPTADORES DE ENTRADA (driving)          │
                    │   Operador (CLI/menú)  →  lee disparador/idea     │
                    └───────────────────────┬───────────────────────────┘
                                             │ invoca caso de uso
                    ┌────────────────────────▼──────────────────────────┐
                    │     ORCHESTR — capa de aplicación / caso de uso     │
                    │  Secuencia los agentes, aplica reintentos,          │
                    │  NO contiene reglas de negocio ni I/O directo       │
                    └──┬─────────┬─────────┬─────────┬─────────┬────────┘
                       │         │         │         │         │
              ┌────────▼──┐ ┌────▼────┐ ┌──▼─────┐ ┌─▼──────┐ ┌▼───────────┐
              │IntakeAgent│ │VoiceAgent│ │ContentAg│ │ImageAg │ │VirAgent    │
              └────────┬──┘ └────┬─────┘ └──┬─────┘ └─┬──────┘ └┬───────────┘
                       │         │          │         │         │
                       │    ┌────▼──────┐   │    ┌────▼──────┐  │
                       │    │DecisionAg │◄──┴────┤PublicatAg │◄─┘
                       │    └────┬──────┘        └────┬──────┘
                       │         │                    │
                    ┌──▼─────────▼────────────────────▼───────────────────┐
                    │        NÚCLEO DE DOMINIO (puro, sin I/O, sin red)     │
                    │  · Máquina de estados de la pieza (draft/…/simulated) │
                    │  · Reglas de decisión (umbral de viralidad)           │
                    │  · Reglas de perfil de voz (validación, no redacción) │
                    │  · Validaciones de entrada                            │
                    └──────────────────────┬────────────────────────────────┘
                                            │ solo a través de PUERTOS (copybooks)
                    ┌───────────────────────▼─────────────────────────────┐
                    │   PUERTOS — contratos abstractos (copybooks)          │
                    │   LLM-PORT · IMAGE-PORT · PUBLISH-PORT · REPO-PORT    │
                    └──┬───────────┬────────────────┬────────────┬────────┘
                       │           │                │            │
              ┌────────▼──┐ ┌──────▼───────┐ ┌──────▼──────┐ ┌──▼────────────┐
              │LLM Adapter│ │Image Adapter │ │Publish/Sim  │ │StateRepository│
              │(bridge    │ │(bridge o     │ │Adapter      │ │(archivo       │
              │ JSON↔HTTP │ │ banco local) │ │(simulador)  │ │ indexado +    │
              │ →Claude)  │ │              │ │             │ │ log append)   │
              └───────────┘ └──────────────┘ └─────────────┘ └───────────────┘
                    ADAPTADORES DE SALIDA (driven) — mundo externo / persistencia
```

**Dirección de dependencias:** siempre de afuera hacia adentro.
`Adaptadores → Puertos → Dominio`. El dominio no conoce ningún adapter concreto ni ninguna librería externa; solo conoce la forma de los registros definidos en los puertos (copybooks). Los agentes dependen del dominio y de los puertos; el `ORCHESTR` depende de los *contratos* de los agentes, nunca de su lógica interna. Ningún programa de dominio contiene una sentencia de I/O de archivo ni de red.

---

## 2. Contratos de agentes

Convención común de envoltorio (aplicada a todas las respuestas):

```json
{
  "status": "OK | VALIDATION_ERROR | ADAPTER_ERROR | PERSISTENCE_ERROR | BUSINESS_REJECTED | FATAL_ERROR",
  "error_code": "STRING | null",
  "error_message": "STRING | null"
}
```

Rangos de código de error por familia (detalle en sección 5): `1xxx` validación · `2xxx` adaptador externo · `3xxx` persistencia · `4xxx` regla de negocio (no es un fallo técnico) · `5xxx` interno/inesperado. Cada agente usa un prefijo propio para que el error sea trazable a su origen.

### 2.1 IntakeAgent (REQ-A1, REQ-A4)
Valida y normaliza el disparador antes de que entre al pipeline.

- **Entrada**
```json
{ "trigger_text": "STRING (1..500 chars)", "requested_by": "STRING" }
```
- **Salida (OK)**
```json
{ "status": "OK", "content_id": "STRING (UUID)", "trigger_text": "STRING (normalizado)" }
```
- **Errores:** `INT-1001` trigger vacío · `INT-1002` trigger excede longitud máxima · `INT-1003` trigger no es texto plano (caracteres no soportados por el charset COBOL del sistema).

### 2.2 VoiceAgent (REQ-B1, REQ-B2, REQ-B3)
No redacta texto: expone el **perfil de voz activo** (reglas de tono, léxico, postura) que `ContentAgent` debe aplicar. Separar este agente permite versionar la hipótesis de voz sin tocar la generación.

- **Entrada**
```json
{ "voice_profile_id": "STRING (opcional, default = perfil activo)" }
```
- **Salida (OK)**
```json
{
  "status": "OK",
  "voice_profile_id": "STRING",
  "voice_profile_version": "INT",
  "tone_directives": ["STRING", "..."],
  "lexical_constraints": ["STRING", "..."]
}
```
- **Errores:** `VOI-1001` perfil solicitado no existe · `VOI-5001` perfil activo mal formado (defecto de configuración, fatal).

### 2.3 ContentAgent (REQ-A1, REQ-A2, REQ-A3, REQ-A5)
Orquesta la llamada al `LLM-PORT` combinando `trigger_text` + directivas de `VoiceAgent`.

- **Entrada**
```json
{
  "content_id": "STRING",
  "trigger_text": "STRING",
  "tone_directives": ["STRING", "..."],
  "lexical_constraints": ["STRING", "..."],
  "max_chars": "INT"
}
```
- **Salida (OK)**
```json
{ "status": "OK", "content_id": "STRING", "generated_text": "STRING", "voice_profile_version": "INT" }
```
- **Errores:** `GEN-1001` entrada incompleta (falta trigger o directivas) · `GEN-2001` adaptador LLM sin respuesta (timeout) · `GEN-2002` respuesta LLM no cumple el formato esperado · `GEN-2003` respuesta LLM excede `max_chars` tras normalización · `GEN-2429` límite de tasa del proveedor (retryable).

### 2.4 ImageAgent (REQ-C1, REQ-C2, REQ-C4)
Recibe la tesis del post (no solo el texto crudo) para producir una imagen pertinente y su justificación.

- **Entrada**
```json
{ "content_id": "STRING", "generated_text": "STRING", "thesis_summary": "STRING" }
```
- **Salida (OK)**
```json
{
  "status": "OK",
  "content_id": "STRING",
  "image_ref": "STRING (identificador o ruta)",
  "image_rationale": "STRING (por qué esta imagen refuerza la tesis)"
}
```
- **Errores:** `IMG-1001` `thesis_summary` vacío · `IMG-2001` adaptador de imagen sin respuesta · `IMG-2002` imagen generada/seleccionada no cumple formato mínimo (dimensiones/tipo).

### 2.5 ViralityAgent (REQ-D1, REQ-D2, REQ-D4)
Produce la señal y su explicación; **no decide** qué pasa con la pieza (eso es `DecisionAgent`, separado para mantener la regla de negocio testeable de forma aislada).

- **Entrada**
```json
{ "content_id": "STRING", "generated_text": "STRING", "image_rationale": "STRING" }
```
- **Salida (OK)**
```json
{
  "status": "OK",
  "content_id": "STRING",
  "virality_level": "LOW | MEDIUM | HIGH",
  "virality_factors": ["STRING", "..."]
}
```
- **Errores:** `VIR-1001` texto insuficiente para evaluar · `VIR-5001` regla de scoring mal configurada (fatal).

### 2.6 DecisionAgent (REQ-D3, REQ-D5) — dominio puro, sin adaptadores
Aplica la regla de negocio "qué hacer con la señal". Es el único agente que **no** llama a ningún puerto externo: solo lee `virality_level` y el estado actual.

- **Entrada**
```json
{ "content_id": "STRING", "current_state": "DRAFT", "virality_level": "LOW | MEDIUM | HIGH" }
```
- **Salida (OK)**
```json
{ "status": "OK", "content_id": "STRING", "decision": "SELECT | DISCARD | FLAG_FOR_REGENERATION", "reason": "STRING" }
```
- **Errores:** `DEC-1001` `current_state` no es un estado válido para decidir (p. ej. ya está `SIMULATED`).

### 2.7 PublicationAgent (REQ-E1..E5)
Solo actúa sobre piezas en estado `SELECTED`. En esta versión, únicamente soporta el modo simulado.

- **Entrada**
```json
{ "content_id": "STRING", "generated_text": "STRING", "image_ref": "STRING", "mode": "SIMULATE" }
```
- **Salida (OK)**
```json
{
  "status": "OK",
  "content_id": "STRING",
  "publish_mode": "SIMULATED",
  "rendered_preview_ref": "STRING (referencia a la vista previa fiel generada)"
}
```
- **Errores:** `PUB-1001` `mode` distinto de `SIMULATE` no soportado en esta versión (devuelve error explícito, nunca publica realmente por defecto) · `PUB-4001` pieza no está en estado `SELECTED` (rechazo de negocio, no técnico).

### 2.8 StateRepository (REQ-F1..F6) — puerto de persistencia, no "agente" de flujo
Único punto de acceso a los archivos de estado. Ver contrato de errores detallado en la sección 5.

- **Entrada (ejemplo: transición)**
```json
{ "content_id": "STRING", "from_state": "STRING", "to_state": "STRING", "reason": "STRING" }
```
- **Salida (OK)**
```json
{ "status": "OK", "content_id": "STRING", "current_state": "STRING", "transition_logged": true }
```
- **Errores:** `REP-3010` contenido no encontrado · `REP-3022` `content_id` duplicado en creación · `REP-3099` fallo de E/S de almacenamiento (retryable) · `REP-5001` error de acceso a archivo no esperado (fatal, indica corrupción o mal uso).

---

## 3. Patrón de arquitectura elegido

**Elegido: hexagonal (puertos y adaptadores) adaptado a COBOL**, con el dominio (máquina de estados + reglas de decisión + validaciones) aislado de todo I/O, y el acceso a LLM/imagen/publicación/persistencia mediado por copybooks-contrato y `CALL` dinámico.

**Alternativa descartada: monolito batch clásico** (un único programa `PROCEDURE DIVISION` que abre archivos, arma el JSON, llama al bridge HTTP y decide todo en línea, estilo job batch tradicional).

| Criterio | Monolito batch clásico | Hexagonal adaptado |
|---|---|---|
| Testear "¿qué decide el sistema con virality=LOW?" | Requiere ejecutar el batch completo (archivo real, red real o stub incrustado) | `DecisionAgent` se prueba con `cobol-unit-test` en milisegundos, sin I/O |
| Cambiar de proveedor de imagen o de LLM | Reescribir el programa principal | Se sustituye el nombre del programa adaptador resuelto en runtime; el dominio no cambia |
| Simular sin red disponible (obligatorio: REQ-E1, sin credenciales) | El "modo simulado" queda mezclado con la lógica real de publicación, alto riesgo de que se filtre una llamada real | El `PublishAdapter` en modo simulado es un programa distinto del que llamaría a LinkedIn real; la selección es explícita y auditable |
| Auditar por qué una pieza fue descartada (REQ-F4) | El razonamiento vive disperso entre variables de trabajo de un único programa largo | `DecisionAgent` devuelve `reason` como parte de su contrato; se persiste tal cual en el log de transiciones |
| Curva de complejidad para una v1 de alcance acotado | Más rápido de escribir al inicio | Ligero costo inicial (definir copybooks de puertos) |

**Justificación central:** el enunciado exige tres propiedades que un monolito batch dificulta estructuralmente: (1) que la señal de viralidad **influya realmente** en una decisión verificable (REQ-D3) — que necesita ser una regla aislada y testeable, no una rama perdida dentro de un programa de 2000 líneas; (2) que una simulación **nunca** se confunda con una publicación real (REQ-E4) — que se garantiza mejor separando el adaptador simulado del real como programas distintos, no como un `IF` dentro del mismo flujo; (3) trazabilidad de estado por pieza (REQ-F1..F6) — que exige un único punto de escritura (repository) en vez de escrituras de archivo dispersas. El costo adicional (definir puertos) es pequeño y se paga una sola vez; el monolito lo evita al principio pero lo cobra en cada prueba y en cada cambio de adaptador después.

---

## 4. Patrones de diseño a nivel de programa COBOL

**Programa como módulo.** Cada agente, adaptador y el repositorio se compilan como programas GnuCOBOL independientes (unidades de compilación separadas). Esto es el equivalente COBOL de una clase/servicio encapsulado: cada uno tiene una única entrada (`LINKAGE SECTION` = su contrato de la sección 2), su propio estado interno no es visible desde fuera, y puede recompilarse o sustituirse sin recompilar el resto del sistema.

**Factory vía `CALL` dinámico (resolución de puertos).** Ningún programa invoca a un adaptador por nombre fijo. El nombre del programa concreto que implementa un puerto (`LLM-PORT`, `IMAGE-PORT`, `PUBLISH-PORT`, `REPO-PORT`) se resuelve en tiempo de ejecución a partir de una variable de configuración (p. ej. "el `PUBLISH-PORT` activo es el simulador" vs. en un futuro "es el adaptador real de LinkedIn"). Es el análogo COBOL de una *factory* / inyección de dependencias: el llamador conoce el contrato (copybook), no la implementación.

**Repository para I/O.** `StateRepository` es el único programa autorizado a abrir/leer/escribir los archivos de estado. Ningún agente accede a un archivo directamente. Esto centraliza la traducción de `FILE STATUS` a errores estructurados (sección 5) y evita que dos programas escriban el mismo registro de forma inconsistente.

**Strategy para reglas de viralidad/decisión.** La regla que traduce `virality_level` en `decision` (sección 2.6) se aísla en su propio programa de dominio, de forma que distintas hipótesis de umbral puedan intercambiarse (hoy una regla fija; el diseño no impide sustituir el programa de reglas sin tocar el resto del pipeline).

**Facade/Orchestrator.** `ORCHESTR` es una fachada: conoce el orden de los agentes y la política de reintentos, pero no contiene reglas de negocio ni construye JSON. Su única responsabilidad es la secuencia y la propagación de errores estructurados hacia el operador.

**Adapter.** Cada adaptador (`LLM`, `Image`, `Publish/Sim`) traduce entre el registro interno (copybook de puerto) y el formato externo (JSON/HTTP o, en el caso del simulador, una vista previa renderizada). Es el único lugar del sistema que "sabe" de formatos externos.

---

## 5. Estrategia de manejo de errores

**Verificación explícita de `FILE STATUS`, no `DECLARATIVES`.** Tras cada verbo de E/S en `StateRepository`, se comprueba el código de 2 dígitos inmediatamente y se traduce a un registro de resultado estructurado (sección "convención común de envoltorio"). Se prefiere la verificación explícita en línea sobre `USE AFTER STANDARD ERROR PROCEDURE` porque las declarativas se ejecutan fuera de línea y complican devolver, de forma síncrona, un `status`/`error_code` al llamador — algo que el contrato de la sección 2 exige siempre.

Mapeo indicativo (no exhaustivo) de `FILE STATUS` → error estructurado:

| FILE STATUS | Significado | Clasificación devuelta |
|---|---|---|
| `00`, `02` | Éxito (`02` = éxito con clave duplicada no única, aceptado) | `OK` |
| `10`, `23` | Fin de archivo / registro no encontrado | `PERSISTENCE_ERROR` → `REP-3010` (no fatal: puede ser una consulta legítima de un id inexistente) |
| `22` | Intento de clave duplicada en creación | `PERSISTENCE_ERROR` → `REP-3022` |
| `30`, `9x` | Error de E/S permanente (disco, bloqueo) | `PERSISTENCE_ERROR` → `REP-3099`, marcado **retryable** |
| `21,34,41,42,43,46,47,48,49` | Errores de secuencia/apertura (uso indebido del archivo) | `FATAL_ERROR` → `REP-5001` (indica defecto de programación, no se reintenta) |

**Clasificación de resultado no es solo "éxito/error".** El envoltorio distingue explícitamente:
- `VALIDATION_ERROR` (1xxx): entrada mal formada — nunca se reintenta, se devuelve al operador.
- `ADAPTER_ERROR` (2xxx): fallo de integración externa (LLM/imagen) — puede ser retryable (timeout, `429`) o no (`400`/formato inválido).
- `PERSISTENCE_ERROR` (3xxx): fallo de archivo — ver tabla arriba.
- `BUSINESS_REJECTED` (4xxx): resultado válido del dominio que no es un "fallo" (p. ej. `PUB-4001` pieza no seleccionable) — nunca se reintenta, es una decisión, no una excepción.
- `FATAL_ERROR` (5xxx): estado que no debería ocurrir bajo uso correcto — se registra y detiene el flujo de esa pieza, no del sistema completo.

**Política de reintentos centralizada en `ORCHESTR`.** Los adaptadores son traductores puros y no reintentan por sí mismos. `ORCHESTR` reintenta únicamente los resultados marcados `retryable` (p. ej. `GEN-2429`, `REP-3099`) con un número acotado de intentos; agota el límite y propaga el error estructurado sin bucles indefinidos.

**Excepciones de JSON (`JSON GENERATE`/`JSON PARSE`).** Cada adaptador verifica el estado de la operación JSON inmediatamente después de generarla/parsearla. Cualquier condición anómala (estructura inesperada, campo que excede la longitud definida en el copybook, tipo no coincidente) se traduce a `ADAPTER_ERROR` con código `2xxx` propio del agente; nunca se deja que una condición JSON no controlada aborte el programa.

---

## 6. Estrategia de testing

Pirámide de pruebas, de mayor a menor volumen:

1. **`cobol-unit-test` sobre el núcleo de dominio (sin I/O, sin red).** Cubre: la máquina de estados (¿qué transiciones son válidas desde cada estado?), `DecisionAgent` (¿qué decisión produce cada `virality_level`?), validaciones de `IntakeAgent`/`VoiceAgent`. Estas pruebas no abren archivos ni llaman adaptadores — corren en milisegundos y son la base de la pirámide.

2. **`cobol-unit-test` sobre la traducción de cada adaptador (registro ↔ JSON).** Se prueba con fixtures JSON fijos incluidos en el repositorio (sin red): dado un registro de entrada, ¿el `LLM Adapter` genera el JSON de request esperado?; dado un JSON de respuesta fijo (incluyendo variantes de error), ¿lo traduce al registro estructurado correcto? Aplica igual a `Image Adapter` y `Publish/Sim Adapter`.

3. **`cobol-unit-test` sobre `StateRepository` con archivo temporal.** Cada prueba crea y destruye su propio archivo indexado de prueba (setup/teardown), verificando el mapeo de `FILE STATUS` de la tabla de la sección 5 con casos reales (crear, duplicar clave, leer inexistente).

4. **Contract tests contra un mock local de la API de Claude.** Este es el único nivel que valida el **límite externo real**: (a) que el request que arma `LLM Adapter` cumple la forma que la API de Claude espera (campos obligatorios, forma del mensaje/prompt); (b) que el adapter interpreta correctamente las variantes de respuesta documentadas del proveedor — éxito, error de validación, límite de tasa, error de servidor, timeout — mapeándolas al `status` estructurado correcto. El mock vive versionado en el repositorio y nunca se sustituye por la red real en estas pruebas, para que sean deterministas y no dependan de una API key.

5. **Prueba de flujo completo (E2E).** Un guion único ejecuta `ORCHESTR` de punta a punta con **todos** los adaptadores en modo stub/simulado (incluido `Publish/Sim` en modo `SIMULATE`), verificando la secuencia observable de estados `draft → selected/discarded → simulated` y que cada transición quedó registrada en el log (REQ-U1, REQ-F4). Esta prueba no sustituye a las de contrato: usa un stub del LLM, no el mock detallado del punto 4, porque su objetivo es el flujo, no el límite externo.

**Regla de separación:** `cobol-unit-test` nunca cruza el límite de red, ni siquiera contra el mock — el mock de Claude se ejecuta como parte de los contract tests (nivel 4), que son la única capa autorizada a levantar ese mock.

---

## 7. Modelo de datos del "estado de contenido"

### 7.1 Entidad `ContentPiece`

| Campo | Descripción | REQ relacionado |
|---|---|---|
| `content_id` | Clave única de la pieza | REQ-F1 |
| `trigger_text` | Idea/tema original normalizado | REQ-A1 |
| `generated_text` | Texto final producido | REQ-A2 |
| `voice_profile_version` | Versión del perfil de voz aplicado | REQ-B2 |
| `image_ref` / `image_rationale` | Referencia a la imagen y su justificación | REQ-C4 |
| `virality_level` / `virality_factors` | Señal y su explicación | REQ-D4 |
| `current_state` | `DRAFT \| SELECTED \| DISCARDED \| SIMULATED \| PUBLISHED` | REQ-F1, REQ-F2 |
| `created_at` / `updated_at` | Marcas de tiempo | REQ-F4 |

### 7.2 Tabla de transiciones válidas

| Desde | Evento | Hacia |
|---|---|---|
| `DRAFT` | `DecisionAgent` → `SELECT` | `SELECTED` |
| `DRAFT` | `DecisionAgent` → `DISCARD` | `DISCARDED` |
| `DRAFT` | `DecisionAgent` → `FLAG_FOR_REGENERATION` | `DRAFT` (nueva iteración; ver decisión abierta en `requirements.md` sobre si es el mismo `content_id` u otro) |
| `SELECTED` | `PublicationAgent` en modo `SIMULATE` | `SIMULATED` |
| `SELECTED` | Operador descarta manualmente | `DISCARDED` |
| `SIMULATED`, `DISCARDED` | — | Terminal (no hay transición saliente) |
| `PUBLISHED` | Reservado para modo real (fuera de alcance de esta versión, ver requirements.md §e) | Terminal |

Cualquier transición no listada en esta tabla es rechazada por el dominio con `DEC-1001`, nunca ejecutada "por defecto".

### 7.3 Persistencia: estrategia de dos archivos

`StateRepository` es el único escritor de ambos archivos, lo que garantiza que nunca diverjan:

1. **Archivo indexado (organización `INDEXED`, clave = `content_id`)** — "vista actual": contiene el registro completo de `ContentPiece` con su `current_state` más reciente. Acceso O(1) por clave, es lo que consulta el operador para ver el estado presente de una pieza (REQ-F1, REQ-F3).

2. **Log secuencial de solo-append (organización secuencial)** — un registro por transición: `content_id, from_state, to_state, reason, timestamp`. Nunca se reescribe ni se borra; reconstruye el historial completo de cualquier pieza (REQ-F4) y sirve como registro de auditoría de por qué se tomó cada decisión.

Esta separación es, en esencia, el equivalente COBOL-nativo de un patrón *snapshot + event log*: el archivo indexado responde "¿cómo está ahora?" y el log responde "¿cómo llegó hasta acá?", sin depender de un motor relacional externo no pedido por el enunciado.

**Supuesto de concurrencia (heredado de la decisión abierta de `requirements.md` sobre alcance de sesión única):** se asume un solo operador escribiendo a la vez, por lo que no se diseña ningún mecanismo de bloqueo distribuido ni transacción de dos fases entre el archivo indexado y el log; si el alcance se ampliara a multi-operador, este supuesto debería revisarse explícitamente.

---

## Apéndice — Trazabilidad requirements → design

| Bloque de requirements.md | Cubierto por |
|---|---|
| (a) Generación de contenido | §2.1, §2.3 (IntakeAgent, ContentAgent) |
| (b) Voz/persona | §2.2 (VoiceAgent) |
| (c) Imagen | §2.4 (ImageAgent) |
| (d) Señal de viralidad | §2.5, §2.6 (ViralityAgent, DecisionAgent) |
| (e) Publicación/simulación | §2.7 (PublicationAgent) |
| (f) Trazabilidad de estado | §2.8, §7 (StateRepository, modelo de datos) |

**Nota técnica no cubierta por requirements.md (supuesto necesario de diseño):** GnuCOBOL no tiene cliente HTTPS nativo; `LLM Adapter` e `Image Adapter` asumen un puente externo mínimo (invocación a un proceso/librería que resuelve la llamada HTTPS) cuya única responsabilidad es transporte — la construcción y validación del JSON permanece en COBOL. Esta es una decisión técnica, no de producto, y se documenta aquí por honestidad de diseño, no como alcance nuevo.
