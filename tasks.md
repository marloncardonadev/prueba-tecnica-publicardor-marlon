# tasks.md — Descomposición en tareas atómicas

Tareas derivadas de [requirements.md](requirements.md) y [design.md](design.md), pensadas para ejecutarse en Claude Code una a la vez, en sesiones cortas. Cada tarea declara: criterio de "hecho" verificable, dependencias (por ID) y capa que toca.

**Capas** (según lo pedido): `dominio` (lógica pura, sin I/O ni red — agentes de negocio, máquina de estados, reglas) · `integración externa` (todo lo que cruza el límite hacia Claude API / banco de imágenes / bridge HTTP) · `infraestructura` (build, archivos, CLI, persistencia como mecanismo). Las tareas de las Fases 4 y 5 no siempre encajan en esas tres — se etiquetan igual con la capa que ejercitan o documentan, y `documentación` cuando no aplica ninguna capa técnica.

**Orden de prioridad** (tal como se pidió): Fase 1 flujo E2E con datos fake → Fase 2 integración real con Claude → Fase 3 manejo de errores → Fase 4 tests → Fase 5 documentación. Dentro de la Fase 1 el orden de IDs es también el orden de ejecución recomendado (respeta dependencias).

---

## Fase 1 — Flujo end-to-end mínimo con datos fake

Objetivo de la fase: al completarla, existe un flujo `trigger → texto → imagen → señal → decisión → estado final` corriendo con adaptadores stub (sin red), demostrable de punta a punta (REQ-U1).

| ID | Tarea | Criterio de "hecho" | Depende de | Capa |
|---|---|---|---|---|
| F1-01 | Estructura de proyecto y build: carpetas por capa (`domain/`, `agents/`, `adapters/`, `ports/`, `test/`), script de build que compila todo con `cobc -x` | Un programa COBOL trivial de humo compila y ejecuta vía el script de build sin error | — | infraestructura |
| F1-02 | Copybooks de contrato común: envoltorio `WS-RESULT` (status/error_code/error_message) y estructura `ContentPiece` (§7.1 de design.md) | Un programa stub que hace `COPY` de ambos copybooks compila con `cobc -x` | F1-01 | dominio (contratos) |
| F1-03 | Redactar la hipótesis de voz de Juan Lucas Barbier: tono, léxico, postura — como valores concretos de `tone_directives`/`lexical_constraints`, documentados en texto, no solo en código | Documento con la hipótesis existe y lista explícitamente qué supuestos son "material" (afectan el producto) según REQ-B2 | — | dominio (datos) |
| F1-04 | Definir la regla heurística de viralidad v1 (qué factores observables del texto producen LOW/MEDIUM/HIGH) | Documento con la regla y al menos un ejemplo por nivel, listo para codificarse en F1-11 | — | dominio (datos) |
| F1-05 | `IntakeAgent`: validación de `trigger_text` (INT-1001/1002/1003) | `cobol-unit-test` cubre los 3 casos de error + 1 caso OK y pasa | F1-02 | dominio |
| F1-06 | Máquina de estados de dominio: valida transiciones de la tabla §7.2 (design.md) | `cobol-unit-test` cubre las 7 filas de la tabla (válidas e inválidas) y pasa | F1-02 | dominio |
| F1-07 | `DecisionAgent`: traduce `virality_level` → `SELECT/DISCARD/FLAG_FOR_REGENERATION` | `cobol-unit-test` cubre los 3 niveles + el caso DEC-1001 (estado no decidible) y pasa | F1-02, F1-06 | dominio |
| F1-08 | `VoiceAgent`: expone el perfil de voz de F1-03 como salida fija (`voice_profile_version`, directivas) | `cobol-unit-test` verifica salida OK con los valores de F1-03 y el caso VOI-1001 (perfil inexistente) | F1-02, F1-03 | dominio |
| F1-09 | `ContentAgent` + `LLM Adapter` **FAKE** (plantilla de texto fija, sin red) implementando `LLM-PORT` | `cobol-unit-test` verifica `generated_text` no vacío, respeta `max_chars`, y compila con `cobc -x` | F1-02, F1-05, F1-08 | dominio + integración externa (stub) |
| F1-10 | `ImageAgent` + `Image Adapter` **FAKE** (banco local de 3-5 imágenes fijas seleccionadas por palabra clave) | `cobol-unit-test` verifica que triggers distintos producen `image_ref` distinto y `image_rationale` no vacío | F1-02, F1-09 | dominio + integración externa (stub) |
| F1-11 | `ViralityAgent` con la regla de F1-04 | `cobol-unit-test` cubre al menos un caso por nivel (LOW/MEDIUM/HIGH) según los ejemplos de F1-04 | F1-02, F1-04, F1-09 | dominio |
| F1-12 | `StateRepository` — snapshot indexado: crear/leer/actualizar `ContentPiece` | `cobol-unit-test` con archivo temporal (setup/teardown) cubre creación, lectura, duplicado (REP-3022), no encontrado (REP-3010) | F1-02 | infraestructura |
| F1-13 | `StateRepository` — log secuencial append-only de transiciones | `cobol-unit-test` verifica que tras N transiciones el log tiene N registros legibles en orden | F1-12 | infraestructura |
| F1-14 | `PublicationAgent` + `Publish/Sim Adapter` **FAKE** (modo `SIMULATE`: genera vista previa como archivo/texto) | `cobol-unit-test` cubre salida `SIMULATED` + `rendered_preview_ref`, y el rechazo PUB-4001 si la pieza no está `SELECTED` | F1-02, F1-07, F1-12 | dominio + integración externa (stub) |
| F1-15 | `ORCHESTR`: encadena F1-05→F1-14 en el orden del pipeline, con todos los adaptadores fake | Ejecución manual desde el binario produce, para un trigger de prueba, una pieza con estado final `SIMULATED` o `DISCARDED` (según la regla) y el log de transiciones lo refleja | F1-05, F1-06, F1-07, F1-08, F1-09, F1-10, F1-11, F1-12, F1-13, F1-14 | dominio (aplicación) |
| F1-16 | CLI/menú de operador: ingresa un trigger y muestra el resultado completo (texto, imagen, señal, estado) | Se ejecuta el binario, se ingresa un trigger de prueba y se observa en pantalla el resultado de punta a punta sin errores de ejecución | F1-15 | infraestructura |

**Checkpoint Fase 1:** con F1-01..F1-16 completas, el flujo E2E con datos fake es demostrable (satisface REQ-U1 en modo stub).

---

## Fase 2 — Integración real con la API de Claude

| ID | Tarea | Criterio de "hecho" | Depende de | Capa |
|---|---|---|---|---|
| F2-01 | Bridge HTTP mínimo (proceso/librería externa invocada desde COBOL, ver nota técnica de design.md) | Invocado manualmente contra un endpoint de prueba (p. ej. un echo server), COBOL captura el cuerpo de la respuesta sin abortar | F1-01 | integración externa |
| F2-02 | `LLM Adapter` real — construcción del request JSON de la API de Claude vía `JSON GENERATE` a partir del registro de `ContentAgent` | `cobol-unit-test` (offline) compara el JSON generado contra un fixture fijo, sin llamar red | F1-02, F1-09 | integración externa |
| F2-03 | `LLM Adapter` real — parseo de respuesta vía `JSON PARSE`, incluidas variantes de error (200/400/429/5xx/timeout) | `cobol-unit-test` con un fixture por variante verifica el mapeo a GEN-2001/2002/2003/2429/OK | F2-02 | integración externa |
| F2-04 | Mock local de la API de Claude para contract tests | El mock se levanta localmente y responde con los fixtures de F2-03; un contract test ejecuta el `LLM Adapter` real contra el mock y valida request + response sin tocar la red real | F2-02, F2-03 | integración externa / testing |
| F2-05 | Conmutar `ContentAgent` al `LLM Adapter` real vía la factory de `CALL` dinámico (F1-09 queda como alternativa seleccionable por configuración) | Con una API key válida en el entorno local, el flujo E2E de F1-16 produce texto generado real; sin key, falla de forma controlada (GEN-2001), no con un crash | F2-01, F2-03, F1-09 | integración externa |
| F2-06 *(opcional, no bloqueante)* | `Image Adapter` real contra un proveedor de generación de imágenes | Mismo criterio que F2-05 pero para imagen; explícitamente opcional — si no se hace, F1-10 (banco local) queda como solución de v1 | F2-01, F1-10 | integración externa |

---

## Fase 3 — Manejo de errores

| ID | Tarea | Criterio de "hecho" | Depende de | Capa |
|---|---|---|---|---|
| F3-01 | Completar el mapeo de `FILE STATUS` en `StateRepository` (design.md §5): retryable (30/9x) y fatal (21/34/41/42/43/46/47/48/49) | `cobol-unit-test` fuerza cada condición (simulada) y verifica el código `REP-xxxx` correcto | F1-12, F1-13 | infraestructura |
| F3-02 | Política de reintentos en `ORCHESTR` para resultados marcados retryable (GEN-2429, REP-3099) | Test de integración simula un fallo transitorio (falla 1 vez, luego OK) y verifica reintento exitoso; simula fallo persistente y verifica que se detiene en el límite configurado, propagando el error estructurado | F1-15, F2-03, F3-01 | dominio (aplicación) |
| F3-03 | Manejo explícito de excepciones `JSON GENERATE`/`JSON PARSE` en todos los adaptadores (LLM e Image) | `cobol-unit-test` con un JSON malformado o con campo que excede longitud produce `ADAPTER_ERROR` 2xxx en vez de abortar el programa | F2-02, F2-03, F1-10 | integración externa |
| F3-04 | Cubrir códigos de error de dominio restantes: VOI-5001 (perfil mal configurado), DEC-1001 en todos los estados terminales | `cobol-unit-test` añade los casos faltantes y pasa | F1-07, F1-08 | dominio |

---

## Fase 4 — Tests

*(La mayoría de la cobertura ya se construyó de forma incremental en Fases 1-3; esta fase cierra lo que falta a nivel de suite completa, no de unidad individual.)*

| ID | Tarea | Criterio de "hecho" | Depende de | Capa |
|---|---|---|---|---|
| F4-01 | Suite completa de contract tests contra el mock de Claude (todas las variantes de design.md §6 nivel 4, no solo las de F2-03) | `make test-contract` (o equivalente) corre todos los casos y pasan, sin red real | F2-04 | testing / integración externa |
| F4-02 | Test E2E automatizado con aserciones (no solo inspección visual como en F1-16): valida estado final y contenido del log de transiciones | Un script (`make test-e2e`) corre el flujo con adaptadores stub y falla si el estado final o el log no coinciden con lo esperado | F1-15 | testing / dominio |
| F4-03 | Verificar cobertura completa de la tabla de transiciones §7.2 en la suite de tests (no solo en F1-06) | Reporte o listado explícito confirma que las 7 filas de la tabla tienen un test asociado | F1-06 | testing / dominio |

---

## Fase 5 — Documentación

| ID | Tarea | Criterio de "hecho" | Depende de | Capa |
|---|---|---|---|---|
| F5-01 | README ejecutable: build (`cobc -x`), cómo correr el flujo E2E con datos fake, cómo correrlo con la API real (variables de entorno necesarias) | Siguiendo el README desde un checkout limpio, un tercero llega al resultado observable sin pasos faltantes ni implícitos | F1-16, F2-05 | documentación |
| F5-02 | Nota de decisiones y supuestos: resolución explícita de cada "decisión abierta" listada en requirements.md (voz, imagen, umbral de viralidad, fidelidad de simulación, etc.) | El documento existe y cada decisión abierta original tiene una resolución concreta registrada, con la razón | F1-03, F1-04, F2-05 | documentación |
| F5-03 | "Qué haría con una semana más": documento breve | El documento existe y cubre al menos los puntos dejados fuera de alcance en requirements.md (integración real de LinkedIn, analítica post-publicación, etc.) | — | documentación |

---

## Notas de uso

- Las tareas de Fase 1 son las únicas con una cadena de dependencias larga; a partir de F1-15 cualquier fase posterior puede avanzar en paralelo si hay más de una sesión disponible (p. ej. F2-01 no depende de F1-15).
- F2-06 se marca opcional deliberadamente: si el tiempo no alcanza, el producto queda igual de demostrable con el banco de imágenes local de F1-10 — no bloquea ninguna tarea posterior.
- Ninguna tarea de Fase 2 en adelante debe alterar el comportamiento por defecto validado en Fase 1: el modo fake/stub debe seguir siendo seleccionable después de F2-05, para no perder la demo reproducible sin credenciales (REQ-E1).
