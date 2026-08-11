# Prueba técnica (24 horas): motor de contenido para LinkedIn

**Candidato:** Marlon

## Contexto

Juan Lucas Barbier quiere publicar contenido breve, relevante y visual en LinkedIn para desarrolladores COBOL y personas que trabajan con mainframes, sistemas legacy y arquitectura de software.

Los territorios iniciales pueden incluir la modernización de mainframes, la aplicación de IA a sistemas legacy, decisiones de arquitectura y la cultura técnica alrededor de estos sistemas. No te entregamos un producto previo, un repositorio, una guía de voz ni una especificación cerrada.

Queremos ver cómo conviertes una necesidad de producto ambigua en algo real, útil y demostrable.

## El desafío

Durante las próximas 24 horas, construye desde cero una primera versión funcional de un producto que permita crear y publicar contenido de LinkedIn de forma autónoma.

El producto debe ser capaz de transformar una idea, un tema o un disparador que tú definas en una publicación corta dirigida a esta audiencia. La publicación debe reflejar una primera interpretación razonable de la voz de Juan Lucas Barbier, incluir una imagen pertinente y mostrar una predicción o señal de potencial de viralidad.

El resultado no debe ser una colección de pantallas o funcionalidades aisladas. Queremos poder recorrer un flujo completo y comprobar cómo una idea se convierte en contenido listo para publicar, cómo se evalúa y cómo llega —o llegaría de forma fiel— a LinkedIn.

## Lo que debe resolver el producto

Decide qué experiencia tiene más sentido, pero tu producto debe resolver estos resultados:

- Crear posts cortos que se sientan escritos para desarrolladores COBOL y profesionales de mainframes, no copy genérico de IA.
- Definir una voz inicial para Juan Lucas Barbier sin recibir ejemplos previos. Puedes investigar, inferir o proponer una hipótesis; deja claro solo los supuestos que cambien de forma importante el producto.
- Incorporar una imagen que refuerce la tesis del post. La imagen debe aportar al contenido, no ser un adorno intercambiable.
- Producir una señal de viralidad útil. No esperamos una predicción científica ni datos históricos que no existen; sí esperamos una hipótesis clara sobre qué podría funcionar y que esa señal influya en una decisión real del flujo: qué publicar, qué mejorar, qué descartar o qué regenerar.
- Resolver la publicación automática en LinkedIn. No se facilitarán credenciales de empresa ni se espera que uses una cuenta personal. Decide cómo demostrar de forma honesta y convincente ese último paso y qué sería necesario para habilitarlo en una cuenta real.
- Hacer visible qué ocurrió con cada pieza de contenido: por ejemplo, si quedó como borrador, fue seleccionada, se descartó, se publicó o se simuló una publicación. Una simulación nunca debe presentarse como una publicación real.

El idioma, la interfaz, el flujo, la frecuencia de publicación, las fuentes de ideas, el nivel de automatización y todas las decisiones técnicas son tuyas.

## Lo que entregas

Entrega un producto que funcione. Una propuesta, una presentación, un Figma o una descripción de arquitectura no sustituyen una implementación ejecutable.

La entrega debe incluir:

- Un repositorio con el producto.
- Un README breve que permita ejecutarlo o recorrer la demostración principal.
- Una nota corta con las decisiones y supuestos que afectaron materialmente al producto.
- Una explicación breve de qué harías después si tuvieras una semana adicional.

Puedes incluir una URL desplegada o un vídeo corto si facilita la revisión, pero no es obligatorio. La revisión no aportará claves, cuentas de LinkedIn ni contenido adicional para completar la demostración.

## Cómo trabajar

Tienes 24 horas desde que recibes esta consigna.

Puedes usar el lenguaje, framework, modelos, proveedores, herramientas y nivel de automatización que consideres adecuados. Puedes usar herramientas de IA durante el desarrollo. No habrá una ronda adicional de aclaraciones: cuando el problema no defina una decisión, eres responsable de tomarla, priorizar y avanzar.

No buscamos una arquitectura perfecta, una plataforma completa ni una respuesta “correcta”. Buscamos un producto pequeño que funcione, con creatividad, criterio de producto y una ejecución rápida bajo incertidumbre.

## Qué valoraremos

Nos importará especialmente:

- Que exista un flujo completo y demostrable, no solo una idea bien explicada.
- La calidad, relevancia y especificidad del contenido para la audiencia COBOL/mainframe.
- Que la voz, la imagen y la predicción de viralidad tengan una función real dentro del producto.
- Cómo transformaste una necesidad abierta en decisiones de producto concretas.
- Tu capacidad para priorizar, recortar alcance y entregar algo convincente en poco tiempo.
- La claridad, honestidad y calidad general de la entrega.

Construye la versión más pequeña que haga que alguien quiera seguir usándola.

---

## Cómo compilar y ejecutar la demo

Requiere GnuCOBOL 3.x (`cobc`) en el PATH. Todos los comandos se ejecutan desde la raíz del repositorio (varios programas usan rutas relativas como `config/linkedin.cfg` u `outputs/simulated-posts/`, que se resuelven contra el directorio desde el que se lanza el binario, no contra la ubicación del `.cbl`).

`CONTENT-PIPELINE.cbl` orquesta 4 agentes (`VOICE-GEN`, `CONTENT-GEN`, `IMAGE-SEL`, `VIRALITY-SCORE`, en [src/agents/](src/agents/)) llamándolos por `CALL` dinámico — por eso cada uno se compila como **módulo enlazable** (`-m`), no como ejecutable, y el orquestador los resuelve en tiempo de ejecución vía `COB_LIBRARY_PATH`.

```bash
mkdir -p build

# 1. Compilar los 4 agentes como modulos enlazables
cobc -m -I src/copybooks -o build/VOICE-GEN      src/agents/VOICE-GEN.cbl
cobc -m -I src/copybooks -o build/CONTENT-GEN    src/agents/CONTENT-GEN.cbl
cobc -m -I src/copybooks -o build/IMAGE-SEL      src/agents/IMAGE-SEL.cbl
cobc -m -I src/copybooks -o build/VIRALITY-SCORE src/agents/VIRALITY-SCORE.cbl

# 2. Compilar el orquestador como ejecutable
cobc -x -I src/copybooks -o build/CONTENT-PIPELINE src/pipeline/CONTENT-PIPELINE.cbl

# 3. Ejecutar (COB_LIBRARY_PATH le dice al runtime donde buscar los modulos de los agentes)
COB_LIBRARY_PATH=build ./build/CONTENT-PIPELINE
```

El programa pide el disparador por consola (`ACCEPT`) y muestra el resultado final (estado, motivo si hubo error, vista previa si quedó `SIMULATED`). Cada transición queda además registrada en `AUDIT_LOG.DAT`, creado en el directorio desde el que se ejecutó.

**Nota de plataforma:** en Windows, `cobc -m` suele generar `.dll` en vez de `.so`; el flag `-o build/NOMBRE` (sin extensión) deja que `cobc` elija la extensión correcta para la plataforma. No se pudo verificar este paso con un compilador real en el entorno donde se escribió este código — si `COB_LIBRARY_PATH` no resuelve los módulos, revisar con `cobc --info` qué extensión y convención usa tu instalación.

---

## PUBLISH-SIM.cbl

Implementa el paso de publicación del pipeline ([design.md](design.md), sección 2.7 — `PublicationAgent`). Construye el payload exacto de la [LinkedIn UGC Post API](https://api.linkedin.com/v2/ugcPosts) (endpoint, headers, body) y luego decide qué hacer con él según si hay credenciales configuradas:

- **Sin `ACCESS_TOKEN` en `config/linkedin.cfg`** (el caso por defecto de esta demo, ver `requirements.md` REQ-E1): escribe ese mismo payload en `outputs/simulated-posts/{content_id}.json`, envuelto en un registro con `"simulation": true` y `"content_state": "SIMULATED"`. Nunca se llama a la red real.
- **Con `ACCESS_TOKEN` presente**: intenta el POST real vía un adaptador `HTTP-BRIDGE` (aún no implementado en este repositorio, ver `tasks.md` tarea F2-01). Si el adaptador no está disponible o LinkedIn no responde `201`, el resultado queda en estado `ERROR` con motivo explícito — nunca se marca `PUBLISHED` salvo una respuesta real y exitosa de LinkedIn.

### Compilar y ejecutar

No depende de ningún copybook ni de los agentes de arriba — se compila solo. Igual que el resto, se ejecuta desde la raíz del repo (usa rutas relativas a `config/linkedin.cfg` y `outputs/simulated-posts/`).

```bash
mkdir -p build
cobc -x -o build/PUBLISH-SIM src/pipeline/PUBLISH-SIM.cbl
./build/PUBLISH-SIM
```

El contenido de entrada (texto, imagen, `content_id`) está fijo en `WORKING-STORAGE` en esta v1; conectarlo a la salida real de `CONTENT-PIPELINE.cbl` es la extensión natural siguiente.

### Qué hace falta para pasar a modo real

Para que el intento de publicación real funcione contra una cuenta de LinkedIn genuina, hacen falta tres cosas que esta demo **no tiene ni pide**:

1. **Client ID y Client Secret** de una app registrada en el [LinkedIn Developer Portal](https://www.linkedin.com/developers/apps), con el producto "Share on LinkedIn" (o "Community Management API") habilitado.
2. **Un token OAuth 2.0 con el scope `w_member_social`** — es el permiso que autoriza crear posts en nombre de la cuenta autenticada. Se obtiene completando el flujo de autorización de LinkedIn (redirect + intercambio de código por token) con el Client ID/Secret del punto anterior.
3. **El URN del autor**, que no es una credencial en sí pero es un prerrequisito real: antes de poder publicar hay que resolver `urn:li:person:{id}` llamando a `/v2/userinfo` (o `/v2/me`) con ese mismo token. `PUBLISH-SIM.cbl` deja ese campo como `{PENDING_OAUTH_ME}` en el payload simulado precisamente porque no hay token con el cual resolverlo.

Con las tres cosas disponibles, basta con completar `config/linkedin.cfg` (`ACCESS_TOKEN=...`) y tener `HTTP-BRIDGE` implementado (tarea F2-01) para que la misma ejecución de `PUBLISH-SIM.cbl` tome la rama real en vez de la simulada — el código de ambas rutas ya existe y comparte la construcción del payload.

