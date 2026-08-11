# Requirements — Motor de contenido LinkedIn (COBOL/mainframe)

Formato: EARS (Easy Approach to Requirements Syntax).
Patrones usados: `WHEN <evento> THE SYSTEM SHALL <respuesta>`, `WHILE <estado> THE SYSTEM SHALL <respuesta>`, `IF <condición> THEN THE SYSTEM SHALL <respuesta>`, y `THE SYSTEM SHALL <respuesta>` para requisitos ubicuos (siempre activos).

Este documento describe **comportamiento observable**, no implementación. Cada sección abre con los requisitos derivados directamente del enunciado y cierra con **Decisiones abiertas** — puntos que el enunciado deja sin definir y que exigen una hipótesis de producto antes de diseñar la solución.

---

## a) Generación de contenido

- REQ-A1: WHEN el usuario proporciona una idea, tema o disparador THE SYSTEM SHALL generar una publicación corta como salida.
- REQ-A2: THE SYSTEM SHALL producir publicaciones cuyo contenido sea específico al dominio COBOL/mainframe/legacy (terminología, problemas y contexto reconocibles por esa audiencia), no texto genérico aplicable a cualquier tema técnico.
- REQ-A3: THE SYSTEM SHALL restringir la extensión de la publicación generada a un formato "corto", coherente con el consumo típico de un post de LinkedIn.
- REQ-A4: THE SYSTEM SHALL permitir que el disparador de contenido (idea/tema) sea definido por quien opera el sistema, sin requerir una fuente externa integrada.
- REQ-A5: WHEN se genera una publicación THE SYSTEM SHALL dejarla disponible para revisión antes de cualquier acción de publicación (ninguna publicación se envía sin pasar por un estado previo revisable).
- REQ-A6: IF el contenido generado no es satisfactorio THEN THE SYSTEM SHALL permitir regenerar o descartar esa pieza sin afectar otras piezas ya generadas.

**Decisiones abiertas — (a):**
- Qué territorios temáticos concretos (de los sugeridos: modernización de mainframes, IA aplicada a legacy, decisiones de arquitectura, cultura técnica) cubre la v1, y si el disparador es texto libre, una lista curada, o ambos.
- Idioma de las publicaciones (el enunciado lo deja abierto explícitamente).
- Si la generación es 100% automática o admite edición humana del texto antes de avanzar en el flujo.

---

## b) Voz / persona (Juan Lucas Barbier)

- REQ-B1: THE SYSTEM SHALL aplicar una voz definida para Juan Lucas Barbier a toda publicación generada, sin haber recibido ejemplos previos de su escritura.
- REQ-B2: WHEN se define la voz inicial THE SYSTEM SHALL documentar los supuestos sobre esa voz que tengan impacto material en el producto (tono, postura, nivel de autoridad técnica, etc.), de forma separada del código/contenido.
- REQ-B3: THE SYSTEM SHALL aplicar la voz de forma consistente entre distintas publicaciones generadas, de modo que sea reconocible como un mismo autor.
- REQ-B4: THE SYSTEM SHALL diferenciar el resultado de un "copy genérico de IA" mediante rasgos de voz identificables (perspectiva, vocabulario, actitud ante el tema) aplicados de forma verificable en el texto de salida.

**Decisiones abiertas — (b):**
- La hipótesis concreta de quién es Juan Lucas Barbier y qué voz se le atribuye (rol, autoridad, tono: técnico-cercano, provocador, mentor, etc.) — es una decisión de producto explícita a documentar, no a inventar silenciosamente.
- Si la voz es un conjunto fijo de reglas/ejemplos o si evoluciona con el uso del sistema.

---

## c) Imagen

- REQ-C1: WHEN se genera una publicación THE SYSTEM SHALL incorporar una imagen asociada a esa publicación.
- REQ-C2: THE SYSTEM SHALL generar o seleccionar la imagen en función de la tesis específica del post (no una imagen decorativa intercambiable entre publicaciones distintas).
- REQ-C3: IF se cambia el contenido central (tesis) de una publicación THEN THE SYSTEM SHALL reflejar ese cambio en la imagen asociada, o señalar explícitamente que la imagen quedó desactualizada.
- REQ-C4: THE SYSTEM SHALL permitir verificar, para cada publicación, qué imagen le corresponde y de qué forma se relaciona con el contenido (trazabilidad mínima de esa relación).

**Decisiones abiertas — (c):**
- Origen de la imagen: generada (a partir de qué descripción/prompt derivado del post) vs. seleccionada de un banco/repositorio existente.
- Estilo visual (diagramas técnicos, ilustración conceptual, fotografía simbólica, texto sobre fondo) — no está definido por el enunciado y condiciona fuertemente la percepción de "pertinencia".

---

## d) Señal de viralidad

- REQ-D1: WHEN se genera una publicación THE SYSTEM SHALL producir una señal o predicción de potencial de viralidad asociada a esa pieza.
- REQ-D2: THE SYSTEM SHALL basar la señal de viralidad en una hipótesis explicable (qué factores del post la sustentan), no presentarla como una predicción estadística validada con datos históricos inexistentes.
- REQ-D3: THE SYSTEM SHALL usar la señal de viralidad para influir en al menos una decisión observable del flujo (por ejemplo: qué pieza avanza a publicación, qué pieza se marca para mejorar, qué pieza se descarta, o qué pieza se regenera).
- REQ-D4: WHEN la señal de viralidad se produce THE SYSTEM SHALL dejar visible el motivo o los factores que la explican, junto al valor/nivel de la señal.
- REQ-D5: IF la señal de viralidad de una pieza está por debajo de un criterio definido por el sistema THEN THE SYSTEM SHALL reflejar esa condición en el estado de esa pieza (ver sección f).

**Decisiones abiertas — (d):**
- Escala/forma de la señal (score numérico, categoría tipo alto/medio/bajo, ranking relativo entre piezas generadas en la misma sesión, etc.).
- El umbral o regla que determina cuándo la señal "descarta", "promueve" o "envía a regenerar" una pieza — debe fijarse como hipótesis explícita.

---

## e) Publicación / simulación

- REQ-E1: THE SYSTEM SHALL resolver el paso de publicación en LinkedIn sin requerir credenciales de una cuenta de empresa ni de una cuenta personal real.
- REQ-E2: WHEN una pieza de contenido se publica de forma simulada THE SYSTEM SHALL representar esa acción de manera fiel al resultado que produciría una publicación real en LinkedIn (contenido, imagen y formato tal como se verían), sin ejecutar una llamada real a LinkedIn.
- REQ-E3: THE SYSTEM SHALL etiquetar de forma inequívoca cualquier publicación simulada como simulación, en cualquier lugar donde esa pieza se muestre.
- REQ-E4: THE SYSTEM SHALL prohibir que una simulación se presente, en cualquier vista o estado, con la misma etiqueta o apariencia que una publicación real.
- REQ-E5: THE SYSTEM SHALL describir, de forma accesible para el revisor, qué sería necesario (en términos de comportamiento/acceso, no de implementación) para habilitar la publicación real en una cuenta de LinkedIn genuina.

**Decisiones abiertas — (e):**
- Nivel de fidelidad de la simulación (por ejemplo: vista previa que imita el layout de un post de LinkedIn vs. un registro textual del intento de publicación).
- Si existe algún modo de publicación real opcional (p. ej. contra una cuenta de pruebas propia del candidato) o si el alcance de la v1 es 100% simulado — el enunciado permite ambas lecturas y debe resolverse como hipótesis.
- Frecuencia/disparo de publicación (manual bajo demanda vs. algún tipo de programación) — explícitamente delegado por el enunciado.

---

## f) Trazabilidad de estado

- REQ-F1: THE SYSTEM SHALL asignar a cada pieza de contenido un estado observable durante todo su ciclo de vida.
- REQ-F2: THE SYSTEM SHALL soportar, como mínimo, los estados mencionados en el enunciado: borrador, seleccionada, descartada, publicada, publicación simulada.
- REQ-F3: WHEN el estado de una pieza cambia THE SYSTEM SHALL hacer visible el nuevo estado sin requerir que el usuario infiera el cambio indirectamente.
- REQ-F4: THE SYSTEM SHALL permitir, para cualquier pieza de contenido, recorrer o consultar su historial de estados desde su creación hasta el estado actual.
- REQ-F5: THE SYSTEM SHALL mantener el estado de cada pieza de forma individual, de modo que una acción sobre una pieza (descartar, publicar, regenerar) no altere el estado de otras piezas.
- REQ-F6: IF una pieza fue publicada de forma simulada THEN THE SYSTEM SHALL conservar visible tanto ese estado como su distinción frente a una publicación real (consistente con REQ-E3/E4).

**Decisiones abiertas — (f):**
- Si el historial de estados persiste entre sesiones o solo durante la sesión activa de la demo.
- Si las transiciones de estado son manuales (acción explícita del usuario), automáticas (disparadas por la señal de viralidad u otra regla), o una combinación — condiciona directamente cómo se demuestra el "flujo completo" pedido en el enunciado.

---

## Requisitos ubicuos (transversales)

- REQ-U1: THE SYSTEM SHALL permitir recorrer, en una sola demostración, el flujo completo desde el disparador de contenido hasta el estado final de la pieza (generación → voz aplicada → imagen → señal de viralidad → decisión → publicación o simulación → estado visible).
- REQ-U2: THE SYSTEM SHALL evitar presentar cualquier resultado simulado, inferido o de hipótesis (voz, viralidad, publicación) como si fuera un hecho verificado externamente.

**Decisión abierta — transversal:**
- Alcance de "sesión única" vs. multi-sesión/multi-usuario: el enunciado no exige multiusuario ni persistencia a largo plazo: se asume alcance de demo de un solo operador salvo que se decida ampliarlo.

---

## Fuera de alcance (explícito, no inventar)

El enunciado no pide, y por tanto no se asume sin indicación adicional:
- Integración real con la API de LinkedIn ni OAuth contra una cuenta real.
- Analítica de rendimiento post-publicación (likes/comentarios reales) — no existen datos históricos y el enunciado lo excluye explícitamente.
- Guía de voz o ejemplos previos de Juan Lucas Barbier (se indica expresamente que no se entregan).
- Un calendario o motor de programación de publicaciones recurrentes, salvo que se decida como hipótesis de producto.
