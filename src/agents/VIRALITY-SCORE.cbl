>>SOURCE FREE
*> VIRALITY-SCORE.cbl
*> Agente ViralityAgent (design.md 2.5), extraido de CONTENT-PIPELINE.cbl
*> (antes 5100-COMPUTE-VIRALITY-SCORE) como programa independiente.
*>
*> v1 (Fase 1 de tasks.md): heuristica por conteo de palabras clave del
*> territorio COBOL/legacy. Punto sobre el TEXTO GENERADO (no el
*> disparador crudo): la senal debe reflejar lo que se publicaria, y es
*> lo que le da sentido real a un reintento de CONTENT-GEN (design.md
*> 2.6, FLAG_FOR_REGENERATION) — si se puntuara el disparador, que nunca
*> cambia entre intentos, un reintento jamas podria mejorar el resultado.
*> La regla definitiva de umbral se documenta en la tarea F1-04 de
*> tasks.md.
IDENTIFICATION DIVISION.
PROGRAM-ID. VIRALITY-SCORE.

DATA DIVISION.
WORKING-STORAGE SECTION.
01  WS-SCAN-UPPER              PIC X(400) VALUE SPACES.
01  WS-KEYWORD-COUNT           PIC 9(3)   VALUE 0.

LINKAGE SECTION.
COPY "VIRALITY-SCORE-IO.cpy".

PROCEDURE DIVISION USING VIRALITY-SCORE-REQUEST VIRALITY-SCORE-RESPONSE.

0000-VIRALITY-SCORE-MAIN.
    MOVE SPACES TO WS-SCAN-UPPER
    MOVE FUNCTION UPPER-CASE(VS-GENERATED-TEXT) TO WS-SCAN-UPPER (1:280)
    MOVE 0 TO WS-KEYWORD-COUNT
    INSPECT WS-SCAN-UPPER TALLYING WS-KEYWORD-COUNT
        FOR ALL 'IA'
        FOR ALL 'COBOL'
        FOR ALL 'LEGACY'
        FOR ALL 'MODERNIZ'
    EVALUATE TRUE
        WHEN WS-KEYWORD-COUNT >= 2
            MOVE 'HIGH' TO VS-VIRALITY-LEVEL
        WHEN WS-KEYWORD-COUNT = 1
            MOVE 'MEDIUM' TO VS-VIRALITY-LEVEL
        WHEN OTHER
            MOVE 'LOW' TO VS-VIRALITY-LEVEL
    END-EVALUATE
    MOVE 'Y' TO VS-STEP-STATUS
    GOBACK.
