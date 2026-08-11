>>SOURCE FREE
*> IMAGE-SEL.cbl
*> Agente ImageAgent (design.md 2.4), extraido de CONTENT-PIPELINE.cbl
*> (antes 4100-SELECT-IMAGE) como programa independiente.
*>
*> v1 (Fase 1 de tasks.md): banco local de 2 imagenes fijas
*> seleccionadas por palabra clave del DISPARADOR (no del texto
*> generado: la imagen representa el tema, no deberia cambiar solo
*> porque CONTENT-GEN reintento la redaccion). Sin proveedor externo.
IDENTIFICATION DIVISION.
PROGRAM-ID. IMAGE-SEL.

DATA DIVISION.
WORKING-STORAGE SECTION.
01  WS-SCAN-UPPER              PIC X(400) VALUE SPACES.
01  WS-KEYWORD-COUNT           PIC 9(3)   VALUE 0.

LINKAGE SECTION.
COPY "IMAGE-SEL-IO.cpy".

PROCEDURE DIVISION USING IMAGE-SEL-REQUEST IMAGE-SEL-RESPONSE.

0000-IMAGE-SEL-MAIN.
    MOVE SPACES TO WS-SCAN-UPPER
    MOVE FUNCTION UPPER-CASE(ISEL-TRIGGER-TEXT) TO WS-SCAN-UPPER (1:200)
    MOVE 0 TO WS-KEYWORD-COUNT
    INSPECT WS-SCAN-UPPER TALLYING WS-KEYWORD-COUNT
        FOR ALL 'IA'
    IF WS-KEYWORD-COUNT > 0
        MOVE 'img-ia-legacy-bridge.png' TO ISEL-IMAGE-REF
    ELSE
        MOVE 'img-mainframe-terminal-verde.png' TO ISEL-IMAGE-REF
    END-IF
    MOVE 'Y' TO ISEL-STEP-STATUS
    GOBACK.
