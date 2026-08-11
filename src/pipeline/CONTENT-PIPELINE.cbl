>>SOURCE FREE
*> CONTENT-PIPELINE.cbl
*> Orquestador del pipeline de una pieza de contenido, implementado como
*> patron State/Workflow: cada estado es un PERFORM independiente sobre
*> STATUS-CODE (88-levels), y cada transicion escribe una entrada en
*> AUDIT-LOG antes de continuar. Ver design.md secciones 1, 4 y 7.
*>
*> Version v1 (Fase 1 de tasks.md): VOICE-GEN, CONTENT-GEN, IMAGE-SEL y
*> VIRALITY-SCORE son agentes extraidos como programas COBOL separados
*> (src/agents/), llamados via CALL dinamico con ON EXCEPTION (design.md
*> 4, factory via CALL). Todos son heuristicas o placeholders locales,
*> sin llamar a ninguna API externa todavia (Fase 2 de tasks.md).
IDENTIFICATION DIVISION.
PROGRAM-ID. CONTENT-PIPELINE.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT OPTIONAL AUDIT-LOG-FILE
        ASSIGN TO "AUDIT_LOG.DAT"
        ORGANIZATION IS SEQUENTIAL
        FILE STATUS IS WS-AUDIT-FILE-STATUS.

DATA DIVISION.
FILE SECTION.
FD  AUDIT-LOG-FILE.
    COPY "AUDIT-ENTRY.cpy".

WORKING-STORAGE SECTION.

01  WS-PIPELINE-STATE.
    05  STATUS-CODE               PIC X(20) VALUE SPACES.
        88  IS-RECEIVED                     VALUE 'RECEIVED'.
        88  IS-DRAFTED                      VALUE 'DRAFTED'.
        88  IS-IMAGED                       VALUE 'IMAGED'.
        88  IS-SCORED                       VALUE 'SCORED'.
        88  IS-SELECTED                     VALUE 'SELECTED'.
        88  IS-DISCARDED                    VALUE 'DISCARDED'.
        88  IS-SIMULATED                    VALUE 'SIMULATED'.
        88  IS-ERROR                        VALUE 'ERROR'.
    05  WS-ERROR-REASON            PIC X(100) VALUE SPACES.

01  WS-CONTENT-DATA.
    05  WS-CONTENT-ID              PIC X(36)  VALUE SPACES.
    05  WS-TRIGGER-TEXT            PIC X(200) VALUE SPACES.
    05  WS-GENERATED-TEXT          PIC X(280) VALUE SPACES.
    05  WS-IMAGE-REF               PIC X(60)  VALUE SPACES.
    05  WS-VIRALITY-LEVEL          PIC X(6)   VALUE SPACES.
        88  VIRALITY-LOW                     VALUE 'LOW'.
        88  VIRALITY-MEDIUM                  VALUE 'MEDIUM'.
        88  VIRALITY-HIGH                    VALUE 'HIGH'.
    05  WS-SIMULATED-PREVIEW       PIC X(400) VALUE SPACES.
    05  WS-TIMESTAMP-RAW           PIC X(21)  VALUE SPACES.

*> Registros de request/response de los agentes extraidos, compartidos
*> con sus LINKAGE SECTION via copybook (ver src/copybooks/*-IO.cpy).
COPY "VOICE-GEN-IO.cpy".
COPY "CONTENT-GEN-IO.cpy".
COPY "IMAGE-SEL-IO.cpy".
COPY "VIRALITY-SCORE-IO.cpy".

01  WS-REGEN-CONTROL.
    *> FLAG_FOR_REGENERATION (design.md 2.6): si la senal de viralidad
    *> sale LOW, se reintenta regenerar el contenido hasta
    *> WS-MAX-REGEN-ATTEMPTS veces antes de descartar la pieza.
    05  WS-REGEN-COUNT             PIC 9(2)   VALUE 0.
    05  WS-MAX-REGEN-ATTEMPTS      PIC 9(2)   VALUE 2.

01  WS-TEST-HOOKS.
    *> Gancho de prueba explicito para CONTENT-GEN: no hay adaptador LLM
    *> real todavia (Fase 2 de tasks.md), asi que la variacion entre
    *> intento inicial y reintento se controla aqui. Fallos de los demas
    *> agentes (VOICE-GEN, CONTENT-GEN, IMAGE-SEL, VIRALITY-SCORE) se
    *> simulan mockeando su CALL desde los tests, no con flags como este.
    05  WS-SIMULATE-REGEN-BOOST    PIC X VALUE 'Y'.
        88  REGEN-BOOST-ENABLED          VALUE 'Y'.

01  WS-STEP-RESULT.
    05  WS-STEP-STATUS             PIC X VALUE 'Y'.
        88  STEP-OK                          VALUE 'Y'.
        88  STEP-FAILED                      VALUE 'N'.
    05  WS-STEP-ERROR-MSG          PIC X(100) VALUE SPACES.

01  WS-AUDIT-CONTROL.
    05  WS-AUDIT-SEQ               PIC 9(9)  VALUE 0.
    05  WS-FROM-STATE              PIC X(20) VALUE SPACES.
    05  WS-TO-STATE                PIC X(20) VALUE SPACES.
    05  WS-AUDIT-REASON            PIC X(100) VALUE SPACES.
    05  WS-AUDIT-FILE-STATUS       PIC XX    VALUE SPACES.
        88  AUDIT-WRITE-OK                  VALUE '00'.
    05  WS-AUDIT-WRITE-FAILED      PIC X     VALUE 'N'.
        88  AUDIT-WRITE-HAS-FAILED          VALUE 'Y'.
    05  WS-AUDIT-TRAIL-DEGRADED    PIC X     VALUE 'N'.
        88  AUDIT-TRAIL-IS-DEGRADED         VALUE 'Y'.
    05  WS-AUDIT-FILE-OPEN         PIC X     VALUE 'N'.

PROCEDURE DIVISION.

0000-MAIN-PIPELINE.
    *> Punto de entrada real del ejecutable. STOP RUN vive solo aqui,
    *> nunca en 0500-RUN-PIPELINE: un test que hace PERFORM 0500 directo
    *> (precargando WS-TRIGGER-TEXT y los ganchos de prueba) necesita
    *> poder inspeccionar el resultado despues, y un STOP RUN a mitad de
    *> un TESTCASE terminaria todo el proceso de pruebas.
    PERFORM 0500-RUN-PIPELINE
    STOP RUN.

0500-RUN-PIPELINE.
    PERFORM 1000-INITIALIZE-PIPELINE
    IF NOT IS-ERROR
        PERFORM 2000-STATE-RECEIVED
    END-IF
    IF NOT IS-ERROR
        PERFORM 3000-STATE-DRAFTED
    END-IF
    IF NOT IS-ERROR
        PERFORM 4000-STATE-IMAGED
    END-IF
    IF NOT IS-ERROR
        PERFORM 5000-STATE-SCORED
    END-IF
    IF NOT IS-ERROR
        PERFORM 5500-RETRY-IF-LOW-SCORE
    END-IF
    IF NOT IS-ERROR
        PERFORM 6000-STATE-DECISION
    END-IF
    IF IS-SELECTED
        PERFORM 7000-STATE-SIMULATED
    END-IF
    PERFORM 9000-FINALIZE-PIPELINE.

*> ---------------------------------------------------------------
*> Estados del pipeline (uno por PERFORM). Cada uno delega el trabajo
*> a su worker (n100-...) y confia el registro de la transicion a
*> 8500-COMMIT-OR-FAIL / 8900-FAIL-STATE.
*> ---------------------------------------------------------------

1000-INITIALIZE-PIPELINE.
    OPEN EXTEND AUDIT-LOG-FILE
    IF WS-AUDIT-FILE-STATUS = '00' OR WS-AUDIT-FILE-STATUS = '05'
        *> '05' = archivo OPTIONAL que no existia y fue creado al abrir;
        *> ambos casos son un arranque valido del log de auditoria.
        MOVE 'Y' TO WS-AUDIT-FILE-OPEN
        MOVE 0 TO WS-REGEN-COUNT
        PERFORM 1100-ASSIGN-CONTENT-ID
    ELSE
        MOVE 'ERROR' TO STATUS-CODE
        STRING 'No se pudo abrir AUDIT-LOG (status=' DELIMITED BY SIZE
               WS-AUDIT-FILE-STATUS DELIMITED BY SIZE
               ')' DELIMITED BY SIZE
          INTO WS-ERROR-REASON
        END-STRING
    END-IF.

1100-ASSIGN-CONTENT-ID.
    MOVE FUNCTION CURRENT-DATE TO WS-TIMESTAMP-RAW
    STRING 'CP-' DELIMITED BY SIZE
           WS-TIMESTAMP-RAW (1:14) DELIMITED BY SIZE
      INTO WS-CONTENT-ID
    END-STRING.

2000-STATE-RECEIVED.
    MOVE 'START' TO WS-FROM-STATE
    PERFORM 2100-CAPTURE-AND-VALIDATE-TRIGGER
    IF STEP-OK
        MOVE 'RECEIVED' TO WS-TO-STATE
        MOVE 'Disparador capturado y validado' TO WS-AUDIT-REASON
        PERFORM 8500-COMMIT-OR-FAIL
    ELSE
        PERFORM 8900-FAIL-STATE
    END-IF.

2100-CAPTURE-AND-VALIDATE-TRIGGER.
    *> Si el llamador ya dejo un valor en WS-TRIGGER-TEXT (un test, o un
    *> futuro CALL desde fuera), no se pide por consola: eso es lo que
    *> permite que los tests fijen el disparador sin bloquearse en un
    *> ACCEPT esperando stdin.
    IF FUNCTION TRIM(WS-TRIGGER-TEXT) = SPACES
        DISPLAY 'Ingrese el disparador (idea/tema): ' WITH NO ADVANCING
        ACCEPT WS-TRIGGER-TEXT
    END-IF
    IF FUNCTION TRIM(WS-TRIGGER-TEXT) = SPACES
        MOVE 'N' TO WS-STEP-STATUS
        MOVE 'El disparador esta vacio' TO WS-STEP-ERROR-MSG
    ELSE
        MOVE 'Y' TO WS-STEP-STATUS
    END-IF.

3000-STATE-DRAFTED.
    MOVE STATUS-CODE TO WS-FROM-STATE
    PERFORM 3050-VOICE-GEN
    IF STEP-OK
        PERFORM 3100-CONTENT-GEN
    END-IF
    IF STEP-OK
        IF WS-REGEN-COUNT = 0
            MOVE 'Perfil de voz aplicado y texto generado (intento inicial)'
                TO WS-AUDIT-REASON
        ELSE
            STRING 'Perfil de voz aplicado y texto regenerado (intento '
                       DELIMITED BY SIZE
                   WS-REGEN-COUNT DELIMITED BY SIZE
                   ')' DELIMITED BY SIZE
              INTO WS-AUDIT-REASON
            END-STRING
        END-IF
        MOVE 'DRAFTED' TO WS-TO-STATE
        PERFORM 8500-COMMIT-OR-FAIL
    ELSE
        PERFORM 8900-FAIL-STATE
    END-IF.

3050-VOICE-GEN.
    *> Llama al agente VOICE-GEN (src/agents/VOICE-GEN.cbl,
    *> design.md 2.2), extraido como programa separado.
    MOVE WS-TRIGGER-TEXT TO VG-TRIGGER-TEXT
    CALL 'VOICE-GEN' USING VOICE-GEN-REQUEST VOICE-GEN-RESPONSE
        ON EXCEPTION
            MOVE 'N' TO WS-STEP-STATUS
            MOVE 'VOI-2001: adaptador VOICE-GEN no disponible' TO WS-STEP-ERROR-MSG
        NOT ON EXCEPTION
            IF VG-STEP-OK
                MOVE 'Y' TO WS-STEP-STATUS
            ELSE
                MOVE 'N' TO WS-STEP-STATUS
                MOVE VG-STEP-ERROR-MSG TO WS-STEP-ERROR-MSG
            END-IF
    END-CALL.

3100-CONTENT-GEN.
    *> Llama al agente CONTENT-GEN (src/agents/CONTENT-GEN.cbl,
    *> design.md 2.3), extraido como programa separado.
    MOVE WS-TRIGGER-TEXT TO CG-TRIGGER-TEXT
    MOVE WS-REGEN-COUNT TO CG-REGEN-COUNT
    MOVE WS-SIMULATE-REGEN-BOOST TO CG-REGEN-BOOST-ENABLED
    CALL 'CONTENT-GEN' USING CONTENT-GEN-REQUEST CONTENT-GEN-RESPONSE
        ON EXCEPTION
            MOVE 'N' TO WS-STEP-STATUS
            MOVE 'GEN-2001: adaptador CONTENT-GEN no disponible' TO WS-STEP-ERROR-MSG
        NOT ON EXCEPTION
            IF CG-STEP-OK
                MOVE CG-GENERATED-TEXT TO WS-GENERATED-TEXT
                MOVE 'Y' TO WS-STEP-STATUS
            ELSE
                MOVE 'N' TO WS-STEP-STATUS
                MOVE CG-STEP-ERROR-MSG TO WS-STEP-ERROR-MSG
            END-IF
    END-CALL.

4000-STATE-IMAGED.
    MOVE STATUS-CODE TO WS-FROM-STATE
    PERFORM 4100-IMAGE-SEL
    IF STEP-OK
        MOVE 'IMAGED' TO WS-TO-STATE
        MOVE 'Imagen asociada segun palabras clave del disparador' TO WS-AUDIT-REASON
        PERFORM 8500-COMMIT-OR-FAIL
    ELSE
        PERFORM 8900-FAIL-STATE
    END-IF.

4100-IMAGE-SEL.
    *> Llama al agente IMAGE-SEL (src/agents/IMAGE-SEL.cbl,
    *> design.md 2.4), extraido como programa separado.
    MOVE WS-TRIGGER-TEXT TO ISEL-TRIGGER-TEXT
    CALL 'IMAGE-SEL' USING IMAGE-SEL-REQUEST IMAGE-SEL-RESPONSE
        ON EXCEPTION
            MOVE 'N' TO WS-STEP-STATUS
            MOVE 'IMG-2001: adaptador IMAGE-SEL no disponible' TO WS-STEP-ERROR-MSG
        NOT ON EXCEPTION
            IF ISEL-STEP-OK
                MOVE ISEL-IMAGE-REF TO WS-IMAGE-REF
                MOVE 'Y' TO WS-STEP-STATUS
            ELSE
                MOVE 'N' TO WS-STEP-STATUS
                MOVE ISEL-STEP-ERROR-MSG TO WS-STEP-ERROR-MSG
            END-IF
    END-CALL.

5000-STATE-SCORED.
    MOVE STATUS-CODE TO WS-FROM-STATE
    PERFORM 5100-VIRALITY-SCORE
    IF STEP-OK
        MOVE 'SCORED' TO WS-TO-STATE
        STRING 'Senal de viralidad calculada: ' DELIMITED BY SIZE
               FUNCTION TRIM(WS-VIRALITY-LEVEL) DELIMITED BY SIZE
          INTO WS-AUDIT-REASON
        END-STRING
        PERFORM 8500-COMMIT-OR-FAIL
    ELSE
        PERFORM 8900-FAIL-STATE
    END-IF.

5100-VIRALITY-SCORE.
    *> Llama al agente VIRALITY-SCORE (src/agents/VIRALITY-SCORE.cbl,
    *> design.md 2.5), extraido como programa separado. Punto sobre el
    *> texto generado (WS-GENERATED-TEXT), no el disparador crudo.
    MOVE WS-GENERATED-TEXT TO VS-GENERATED-TEXT
    CALL 'VIRALITY-SCORE' USING VIRALITY-SCORE-REQUEST VIRALITY-SCORE-RESPONSE
        ON EXCEPTION
            MOVE 'N' TO WS-STEP-STATUS
            MOVE 'VIR-2001: adaptador VIRALITY-SCORE no disponible' TO WS-STEP-ERROR-MSG
        NOT ON EXCEPTION
            IF VS-STEP-OK
                MOVE VS-VIRALITY-LEVEL TO WS-VIRALITY-LEVEL
                MOVE 'Y' TO WS-STEP-STATUS
            ELSE
                MOVE 'N' TO WS-STEP-STATUS
                MOVE VS-STEP-ERROR-MSG TO WS-STEP-ERROR-MSG
            END-IF
    END-CALL.

5500-RETRY-IF-LOW-SCORE.
    *> FLAG_FOR_REGENERATION (design.md 2.6): mientras la senal siga LOW
    *> y queden intentos, se vuelve a redactar y re-puntuar. Termina en
    *> exito (deja de ser LOW), en ERROR (algun paso fallo durante el
    *> reintento), o agotado (sigue LOW tras WS-MAX-REGEN-ATTEMPTS) — en
    *> los tres casos 6000-STATE-DECISION decide con datos consistentes.
    PERFORM UNTIL NOT VIRALITY-LOW
               OR IS-ERROR
               OR WS-REGEN-COUNT >= WS-MAX-REGEN-ATTEMPTS
        ADD 1 TO WS-REGEN-COUNT
        PERFORM 3000-STATE-DRAFTED
        IF NOT IS-ERROR
            PERFORM 4000-STATE-IMAGED
        END-IF
        IF NOT IS-ERROR
            PERFORM 5000-STATE-SCORED
        END-IF
    END-PERFORM.

6000-STATE-DECISION.
    MOVE STATUS-CODE TO WS-FROM-STATE
    PERFORM 6100-EVALUATE-DECISION
    IF STEP-OK
        STRING 'Decision por regla de viralidad (' DELIMITED BY SIZE
               FUNCTION TRIM(WS-VIRALITY-LEVEL) DELIMITED BY SIZE
               ')' DELIMITED BY SIZE
          INTO WS-AUDIT-REASON
        END-STRING
        PERFORM 8500-COMMIT-OR-FAIL
    ELSE
        PERFORM 8900-FAIL-STATE
    END-IF.

6100-EVALUATE-DECISION.
    *> Regla de DecisionAgent (design.md 2.6 / REQ-D3): LOW descarta,
    *> MEDIUM/HIGH seleccionan para publicacion (simulada).
    IF VIRALITY-LOW
        MOVE 'DISCARDED' TO WS-TO-STATE
    ELSE
        MOVE 'SELECTED' TO WS-TO-STATE
    END-IF
    MOVE 'Y' TO WS-STEP-STATUS.

7000-STATE-SIMULATED.
    MOVE STATUS-CODE TO WS-FROM-STATE
    PERFORM 7100-RENDER-SIMULATED-PREVIEW
    IF STEP-OK
        MOVE 'SIMULATED' TO WS-TO-STATE
        MOVE 'Vista previa simulada generada, no se publico en LinkedIn' TO WS-AUDIT-REASON
        PERFORM 8500-COMMIT-OR-FAIL
    ELSE
        PERFORM 8900-FAIL-STATE
    END-IF.

7100-RENDER-SIMULATED-PREVIEW.
    *> Placeholder de PublicationAgent en modo SIMULATE (design.md 2.7):
    *> nunca llama a la API real de LinkedIn (REQ-E1/E4).
    STRING '[SIMULACION] ' DELIMITED BY SIZE
           FUNCTION TRIM(WS-GENERATED-TEXT) DELIMITED BY SIZE
           ' | imagen=' DELIMITED BY SIZE
           FUNCTION TRIM(WS-IMAGE-REF) DELIMITED BY SIZE
      INTO WS-SIMULATED-PREVIEW
    END-STRING
    MOVE 'Y' TO WS-STEP-STATUS.

*> ---------------------------------------------------------------
*> Infraestructura de transicion/auditoria, compartida por todos los
*> estados. Invariante: STATUS-CODE solo cambia junto con una entrada
*> de auditoria de esa misma transicion (8500), o hacia 'ERROR' con
*> motivo explicito (8900) — nunca de otra forma.
*> ---------------------------------------------------------------

8000-WRITE-AUDIT-ENTRY.
    ADD 1 TO WS-AUDIT-SEQ
    MOVE WS-AUDIT-SEQ          TO AUDIT-SEQ-NUM
    MOVE WS-CONTENT-ID         TO AUDIT-CONTENT-ID
    MOVE FUNCTION CURRENT-DATE TO AUDIT-TIMESTAMP
    MOVE WS-FROM-STATE         TO AUDIT-FROM-STATE
    MOVE WS-TO-STATE           TO AUDIT-TO-STATE
    MOVE WS-AUDIT-REASON       TO AUDIT-REASON
    WRITE AUDIT-ENTRY
    IF AUDIT-WRITE-OK
        MOVE 'N' TO WS-AUDIT-WRITE-FAILED
    ELSE
        MOVE 'Y' TO WS-AUDIT-WRITE-FAILED
        MOVE 'Y' TO WS-AUDIT-TRAIL-DEGRADED
    END-IF.

8500-COMMIT-OR-FAIL.
    *> Si la auditoria de esta transicion no se pudo escribir, la
    *> transicion en si se considera fallida: STATUS-CODE nunca avanza
    *> sin su registro correspondiente en AUDIT-LOG.
    PERFORM 8000-WRITE-AUDIT-ENTRY
    IF AUDIT-WRITE-HAS-FAILED
        STRING 'No se pudo registrar la auditoria de la transicion a '
                   DELIMITED BY SIZE
               FUNCTION TRIM(WS-TO-STATE) DELIMITED BY SIZE
          INTO WS-STEP-ERROR-MSG
        END-STRING
        PERFORM 8900-FAIL-STATE
    ELSE
        MOVE WS-TO-STATE TO STATUS-CODE
    END-IF.

8900-FAIL-STATE.
    *> Unico camino hacia ERROR. Se llama a 8000 en vez de 8500 para no
    *> reintentar indefinidamente si el propio log de auditoria esta
    *> fallando: como maximo se hace un intento de registrar el motivo
    *> del fallo; si tambien falla, WS-AUDIT-TRAIL-DEGRADED lo refleja,
    *> pero STATUS-CODE y WS-ERROR-REASON quedan fijados igual, nunca
    *> ambiguos.
    MOVE 'ERROR' TO WS-TO-STATE
    MOVE WS-STEP-ERROR-MSG TO WS-AUDIT-REASON
    PERFORM 8000-WRITE-AUDIT-ENTRY
    MOVE 'ERROR' TO STATUS-CODE
    MOVE WS-STEP-ERROR-MSG TO WS-ERROR-REASON.

9000-FINALIZE-PIPELINE.
    IF WS-AUDIT-FILE-OPEN = 'Y'
        CLOSE AUDIT-LOG-FILE
    END-IF
    DISPLAY SPACE
    DISPLAY '--- Resultado del pipeline ---'
    DISPLAY 'content_id : ' FUNCTION TRIM(WS-CONTENT-ID)
    DISPLAY 'estado     : ' FUNCTION TRIM(STATUS-CODE)
    IF IS-ERROR
        DISPLAY 'motivo     : ' FUNCTION TRIM(WS-ERROR-REASON)
    END-IF
    IF IS-SIMULATED
        DISPLAY 'preview    : ' FUNCTION TRIM(WS-SIMULATED-PREVIEW)
    END-IF
    IF AUDIT-TRAIL-IS-DEGRADED
        DISPLAY 'AVISO: una o mas entradas de auditoria no pudieron escribirse.'
    END-IF.
