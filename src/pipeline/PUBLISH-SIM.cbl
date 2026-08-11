>>SOURCE FREE
*> PUBLISH-SIM.cbl
*> Implementa PublicationAgent + Publish/Sim Adapter (design.md 2.7):
*> si hay ACCESS_TOKEN en config/linkedin.cfg intenta publicar de verdad
*> vía LinkedIn UGC Post API; si no lo hay (caso por defecto de esta
*> demo, ver REQ-E1), construye el payload exacto que se habria enviado
*> y lo guarda en outputs/simulated-posts/, marcando el contenido como
*> 'SIMULATED'. El programa nunca marca 'PUBLISHED' salvo una respuesta
*> HTTP 201 real de LinkedIn (REQ-E4: una simulacion nunca se presenta
*> como publicacion real).
*>
*> v1 (Fase 1/2 de tasks.md): el contenido de entrada esta fijo en
*> WORKING-STORAGE en vez de venir de CONTENT-PIPELINE.cbl vía CALL;
*> conectar ambos programas es la tarea natural siguiente (7000-STATE-
*> SIMULATED en CONTENT-PIPELINE.cbl pasaria a llamar a este programa).
*> El intento de publicacion real depende de un programa 'HTTP-BRIDGE'
*> que todavia no existe en este repositorio (tarea F2-01 de tasks.md);
*> si no esta disponible, se reporta como error de adaptador, nunca como
*> exito silencioso.
IDENTIFICATION DIVISION.
PROGRAM-ID. PUBLISH-SIM.

ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT OPTIONAL CONFIG-FILE
        ASSIGN TO "config/linkedin.cfg"
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-CONFIG-FILE-STATUS.

    SELECT SIM-OUTPUT-FILE
        ASSIGN TO WS-OUTPUT-PATH
        ORGANIZATION IS LINE SEQUENTIAL
        FILE STATUS IS WS-OUTPUT-FILE-STATUS.

DATA DIVISION.
FILE SECTION.
FD  CONFIG-FILE.
    01  WS-CONFIG-LINE            PIC X(200).

FD  SIM-OUTPUT-FILE.
    01  WS-OUTPUT-RECORD          PIC X(1300).

WORKING-STORAGE SECTION.

01  WS-CONFIG-DATA.
    05  WS-ACCESS-TOKEN           PIC X(300) VALUE SPACES.
    05  WS-HAS-TOKEN              PIC X      VALUE 'N'.
        88  TOKEN-PRESENT                    VALUE 'Y'.
    05  WS-CONFIG-FILE-STATUS     PIC XX     VALUE SPACES.
    05  WS-CONFIG-KEY             PIC X(40)  VALUE SPACES.
    05  WS-CONFIG-VALUE           PIC X(300) VALUE SPACES.
    05  WS-CONFIG-EQ-POS          PIC 9(4)   VALUE 0.
    05  WS-CONFIG-EOF             PIC X      VALUE 'N'.
        88  CONFIG-AT-END                    VALUE 'Y'.

*> Entrada de demo (Fase 1): sustituye a la llamada real del
*> orquestador. El texto incluye una comilla a proposito para probar
*> el escapado JSON de 3100-ESCAPE-GENERATED-TEXT.
01  WS-CONTENT-INPUT.
    05  WS-CONTENT-ID             PIC X(36)  VALUE 'CP-DEMO-0001'.
    05  WS-GENERATED-TEXT         PIC X(280) VALUE
        'Todo el mundo dice "reescribamos todo". Yo prefiero no reescribir sin entender el batch window que rompo.'.
    05  WS-IMAGE-REF              PIC X(60)  VALUE 'img-mainframe-terminal-verde.png'.
    05  CONTENT-STATE             PIC X(20)  VALUE 'SELECTED'.
        88  STATE-IS-SELECTED                VALUE 'SELECTED'.
        88  STATE-IS-SIMULATED               VALUE 'SIMULATED'.
        88  STATE-IS-PUBLISHED               VALUE 'PUBLISHED'.
        88  STATE-IS-ERROR                   VALUE 'ERROR'.

01  WS-JSON-BUILD.
    05  WS-ESCAPED-TEXT           PIC X(600) VALUE SPACES.
    05  WS-ESCAPE-CHAR            PIC X      VALUE SPACE.
    05  WS-ESCAPE-IN-POS          PIC 9(4)   VALUE 0.
    05  WS-ESCAPE-IN-LEN          PIC 9(4)   VALUE 0.
    05  WS-ESCAPE-OUT-POS         PIC 9(4)   VALUE 0.
    05  WS-UGC-BODY-JSON          PIC X(1200) VALUE SPACES.

01  WS-STEP-RESULT.
    05  WS-STEP-STATUS            PIC X      VALUE 'Y'.
        88  STEP-OK                          VALUE 'Y'.
        88  STEP-FAILED                      VALUE 'N'.
    05  WS-STEP-ERROR-MSG         PIC X(150) VALUE SPACES.

01  WS-OUTPUT-CONTROL.
    05  WS-OUTPUT-PATH            PIC X(200) VALUE SPACES.
    05  WS-OUTPUT-LINE            PIC X(1300) VALUE SPACES.
    05  WS-OUTPUT-FILE-STATUS     PIC XX     VALUE SPACES.
    05  WS-TIMESTAMP-RAW          PIC X(21)  VALUE SPACES.

*> Contrato preliminar hacia el futuro HTTP-BRIDGE (ver tarea F2-01 de
*> tasks.md). BR-BODY reutiliza el mismo JSON que se escribe en el
*> archivo simulado: una sola construccion del payload para ambos
*> caminos (real y simulado).
01  WS-BRIDGE-REQUEST.
    05  BR-METHOD                 PIC X(10)  VALUE 'POST'.
    05  BR-URL                    PIC X(200) VALUE
        'https://api.linkedin.com/v2/ugcPosts'.
    05  BR-AUTH-HEADER            PIC X(320) VALUE SPACES.
    05  BR-BODY                   PIC X(1200) VALUE SPACES.

01  WS-BRIDGE-RESPONSE.
    05  BR-HTTP-STATUS            PIC 9(3)   VALUE 0.
    05  BR-RESPONSE-BODY          PIC X(1000) VALUE SPACES.

PROCEDURE DIVISION.

0000-MAIN-PUBLISH.
    PERFORM 1000-LOAD-CONFIG
    IF STATE-IS-SELECTED
        PERFORM 3000-BUILD-UGC-BODY-JSON
        IF STEP-OK
            IF TOKEN-PRESENT
                PERFORM 4000-ATTEMPT-REAL-PUBLISH
            ELSE
                PERFORM 5000-WRITE-SIMULATED-OUTPUT
            END-IF
        END-IF
    ELSE
        MOVE 'N' TO WS-STEP-STATUS
        MOVE 'PUB-4001: la pieza no esta en estado SELECTED' TO WS-STEP-ERROR-MSG
    END-IF
    PERFORM 9000-REPORT-RESULT
    STOP RUN.

*> ---------------------------------------------------------------
*> Config: solo ACCESS_TOKEN decide el modo (real vs. simulado). La
*> ausencia del archivo, o del valor, es el caso esperado por defecto
*> en esta demo (REQ-E1) y no un error.
*> ---------------------------------------------------------------

1000-LOAD-CONFIG.
    OPEN INPUT CONFIG-FILE
    IF WS-CONFIG-FILE-STATUS = '00' OR WS-CONFIG-FILE-STATUS = '05'
        PERFORM 1100-READ-CONFIG-LINES
        CLOSE CONFIG-FILE
    END-IF.

1100-READ-CONFIG-LINES.
    MOVE 'N' TO WS-CONFIG-EOF
    PERFORM UNTIL CONFIG-AT-END
        READ CONFIG-FILE
            AT END
                MOVE 'Y' TO WS-CONFIG-EOF
            NOT AT END
                PERFORM 1200-PARSE-CONFIG-LINE
        END-READ
    END-PERFORM.

1200-PARSE-CONFIG-LINE.
    *> Solo se parte en el PRIMER '='. Un UNSTRING con dos receptores
    *> partiria tambien por cualquier '=' dentro del valor, y un token
    *> OAuth real casi siempre trae '=' de relleno base64 al final.
    IF FUNCTION TRIM(WS-CONFIG-LINE) NOT = SPACES
       AND WS-CONFIG-LINE (1:1) NOT = '#'
        MOVE 1 TO WS-CONFIG-EQ-POS
        UNSTRING WS-CONFIG-LINE DELIMITED BY '='
            INTO WS-CONFIG-KEY
            WITH POINTER WS-CONFIG-EQ-POS
        END-UNSTRING
        IF FUNCTION TRIM(WS-CONFIG-KEY) = 'ACCESS_TOKEN'
           AND WS-CONFIG-EQ-POS <= LENGTH OF WS-CONFIG-LINE
            MOVE WS-CONFIG-LINE (WS-CONFIG-EQ-POS:) TO WS-CONFIG-VALUE
            IF FUNCTION TRIM(WS-CONFIG-VALUE) NOT = SPACES
                MOVE FUNCTION TRIM(WS-CONFIG-VALUE) TO WS-ACCESS-TOKEN
                MOVE 'Y' TO WS-HAS-TOKEN
            END-IF
        END-IF
    END-IF.

*> ---------------------------------------------------------------
*> Construccion del payload UGC Post. Se hace una sola vez y se
*> reutiliza tanto para el intento real (BR-BODY) como para el
*> archivo simulado, para no mantener dos representaciones del mismo
*> contrato externo.
*> ---------------------------------------------------------------

3000-BUILD-UGC-BODY-JSON.
    PERFORM 3100-ESCAPE-GENERATED-TEXT
    IF STEP-OK
        PERFORM 3200-ASSEMBLE-BODY
    END-IF.

3100-ESCAPE-GENERATED-TEXT.
    MOVE SPACES TO WS-ESCAPED-TEXT
    MOVE FUNCTION LENGTH(FUNCTION TRIM(WS-GENERATED-TEXT)) TO WS-ESCAPE-IN-LEN
    MOVE 1 TO WS-ESCAPE-OUT-POS
    MOVE 'Y' TO WS-STEP-STATUS
    PERFORM VARYING WS-ESCAPE-IN-POS FROM 1 BY 1
            UNTIL WS-ESCAPE-IN-POS > WS-ESCAPE-IN-LEN
               OR STEP-FAILED
        MOVE WS-GENERATED-TEXT (WS-ESCAPE-IN-POS:1) TO WS-ESCAPE-CHAR
        IF WS-ESCAPE-OUT-POS > 598
            *> Limite defensivo: WS-ESCAPED-TEXT tiene tamano fijo y se
            *> escribe por posicion (reference modification), asi que
            *> desbordarlo silenciosamente corromperia memoria en vez
            *> de solo truncar texto.
            MOVE 'N' TO WS-STEP-STATUS
            MOVE 'GEN-2003: el texto generado no se pudo escapar de forma segura'
                TO WS-STEP-ERROR-MSG
        ELSE
            EVALUATE WS-ESCAPE-CHAR
                WHEN '"'
                    MOVE '\' TO WS-ESCAPED-TEXT (WS-ESCAPE-OUT-POS:1)
                    MOVE '"' TO WS-ESCAPED-TEXT (WS-ESCAPE-OUT-POS + 1:1)
                    ADD 2 TO WS-ESCAPE-OUT-POS
                WHEN '\'
                    MOVE '\' TO WS-ESCAPED-TEXT (WS-ESCAPE-OUT-POS:1)
                    MOVE '\' TO WS-ESCAPED-TEXT (WS-ESCAPE-OUT-POS + 1:1)
                    ADD 2 TO WS-ESCAPE-OUT-POS
                WHEN OTHER
                    MOVE WS-ESCAPE-CHAR TO WS-ESCAPED-TEXT (WS-ESCAPE-OUT-POS:1)
                    ADD 1 TO WS-ESCAPE-OUT-POS
            END-EVALUATE
        END-IF
    END-PERFORM.

3200-ASSEMBLE-BODY.
    STRING '{"author":"urn:li:person:{PENDING_OAUTH_ME}",' DELIMITED BY SIZE
           '"lifecycleState":"PUBLISHED",' DELIMITED BY SIZE
           '"specificContent":{"com.linkedin.ugc.ShareContent":{' DELIMITED BY SIZE
           '"shareCommentary":{"text":"' DELIMITED BY SIZE
           FUNCTION TRIM(WS-ESCAPED-TEXT) DELIMITED BY SIZE
           '"},' DELIMITED BY SIZE
           '"shareMediaCategory":"IMAGE",' DELIMITED BY SIZE
           '"media":[{"status":"READY",' DELIMITED BY SIZE
           '"description":{"text":"Imagen generada para el post"},' DELIMITED BY SIZE
           '"media":"urn:li:digitalmediaAsset:{PENDING_ASSET_UPLOAD}",' DELIMITED BY SIZE
           '"title":{"text":"' DELIMITED BY SIZE
           FUNCTION TRIM(WS-IMAGE-REF) DELIMITED BY SIZE
           '"}}]}},' DELIMITED BY SIZE
           '"visibility":{"com.linkedin.ugc.MemberNetworkVisibility":"PUBLIC"}}' DELIMITED BY SIZE
      INTO WS-UGC-BODY-JSON
      ON OVERFLOW
          MOVE 'N' TO WS-STEP-STATUS
          MOVE 'GEN-2003: el cuerpo del post excede el tamano maximo soportado'
              TO WS-STEP-ERROR-MSG
      NOT ON OVERFLOW
          MOVE 'Y' TO WS-STEP-STATUS
    END-STRING.

*> ---------------------------------------------------------------
*> Camino real. No se ejecuta en esta demo porque WS-HAS-TOKEN queda
*> en 'N' (config/linkedin.cfg se entrega vacio a proposito). Si
*> HTTP-BRIDGE no esta enlazado, ON EXCEPTION lo convierte en un error
*> de adaptador en vez de abortar el programa o fingir exito.
*> ---------------------------------------------------------------

4000-ATTEMPT-REAL-PUBLISH.
    MOVE WS-UGC-BODY-JSON TO BR-BODY
    STRING 'Bearer ' DELIMITED BY SIZE
           FUNCTION TRIM(WS-ACCESS-TOKEN) DELIMITED BY SIZE
      INTO BR-AUTH-HEADER
    END-STRING
    CALL 'HTTP-BRIDGE' USING WS-BRIDGE-REQUEST WS-BRIDGE-RESPONSE
        ON EXCEPTION
            MOVE 'N' TO WS-STEP-STATUS
            MOVE 'PUB-2001: adaptador HTTP-BRIDGE no disponible (pendiente, ver F2-01 de tasks.md)'
                TO WS-STEP-ERROR-MSG
            MOVE 'ERROR' TO CONTENT-STATE
        NOT ON EXCEPTION
            IF BR-HTTP-STATUS = 201
                MOVE 'Y' TO WS-STEP-STATUS
                MOVE 'PUBLISHED' TO CONTENT-STATE
            ELSE
                MOVE 'N' TO WS-STEP-STATUS
                STRING 'PUB-2002: LinkedIn respondio HTTP ' DELIMITED BY SIZE
                       BR-HTTP-STATUS DELIMITED BY SIZE
                  INTO WS-STEP-ERROR-MSG
                END-STRING
                MOVE 'ERROR' TO CONTENT-STATE
            END-IF
    END-CALL.

*> ---------------------------------------------------------------
*> Camino simulado (por defecto en esta demo). Escribe el JSON exacto
*> que se habria enviado -endpoint, headers y body- envuelto en un
*> registro que se marca 'simulation: true' sin ambiguedad, y deja el
*> contenido en 'SIMULATED', nunca en 'PUBLISHED'.
*> ---------------------------------------------------------------

5000-WRITE-SIMULATED-OUTPUT.
    PERFORM 5100-BUILD-OUTPUT-PATH
    OPEN OUTPUT SIM-OUTPUT-FILE
    IF WS-OUTPUT-FILE-STATUS NOT = '00'
        MOVE 'N' TO WS-STEP-STATUS
        STRING 'PUB-3001: no se pudo crear el archivo de salida (status='
                   DELIMITED BY SIZE
               WS-OUTPUT-FILE-STATUS DELIMITED BY SIZE
               ')' DELIMITED BY SIZE
          INTO WS-STEP-ERROR-MSG
        END-STRING
    ELSE
        MOVE 'Y' TO WS-STEP-STATUS
        PERFORM 5200-WRITE-OUTPUT-LINES
        CLOSE SIM-OUTPUT-FILE
        IF STEP-OK
            MOVE 'SIMULATED' TO CONTENT-STATE
        ELSE
            MOVE 'ERROR' TO CONTENT-STATE
        END-IF
    END-IF.

5100-BUILD-OUTPUT-PATH.
    MOVE SPACES TO WS-OUTPUT-PATH
    STRING 'outputs/simulated-posts/' DELIMITED BY SIZE
           FUNCTION TRIM(WS-CONTENT-ID) DELIMITED BY SIZE
           '.json' DELIMITED BY SIZE
      INTO WS-OUTPUT-PATH
    END-STRING.

5200-WRITE-OUTPUT-LINES.
    MOVE FUNCTION CURRENT-DATE TO WS-TIMESTAMP-RAW

    MOVE '{' TO WS-OUTPUT-LINE
    PERFORM 5900-WRITE-LINE

    MOVE '  "simulation": true,' TO WS-OUTPUT-LINE
    PERFORM 5900-WRITE-LINE

    MOVE '  "note": "Este archivo representa una publicacion SIMULADA. Nunca se envio a LinkedIn.",'
        TO WS-OUTPUT-LINE
    PERFORM 5900-WRITE-LINE

    STRING '  "generated_at": "' DELIMITED BY SIZE
           WS-TIMESTAMP-RAW (1:14) DELIMITED BY SIZE
           '",' DELIMITED BY SIZE
      INTO WS-OUTPUT-LINE
    END-STRING
    PERFORM 5900-WRITE-LINE

    STRING '  "content_id": "' DELIMITED BY SIZE
           FUNCTION TRIM(WS-CONTENT-ID) DELIMITED BY SIZE
           '",' DELIMITED BY SIZE
      INTO WS-OUTPUT-LINE
    END-STRING
    PERFORM 5900-WRITE-LINE

    MOVE '  "content_state": "SIMULATED",' TO WS-OUTPUT-LINE
    PERFORM 5900-WRITE-LINE

    MOVE '  "would_have_called": {' TO WS-OUTPUT-LINE
    PERFORM 5900-WRITE-LINE

    MOVE '    "method": "POST",' TO WS-OUTPUT-LINE
    PERFORM 5900-WRITE-LINE

    MOVE '    "endpoint": "https://api.linkedin.com/v2/ugcPosts",' TO WS-OUTPUT-LINE
    PERFORM 5900-WRITE-LINE

    MOVE '    "headers": {' TO WS-OUTPUT-LINE
    PERFORM 5900-WRITE-LINE

    MOVE '      "Authorization": "Bearer <ACCESS_TOKEN no configurado en esta demo>",'
        TO WS-OUTPUT-LINE
    PERFORM 5900-WRITE-LINE

    MOVE '      "X-Restli-Protocol-Version": "2.0.0",' TO WS-OUTPUT-LINE
    PERFORM 5900-WRITE-LINE

    MOVE '      "Content-Type": "application/json"' TO WS-OUTPUT-LINE
    PERFORM 5900-WRITE-LINE

    MOVE '    },' TO WS-OUTPUT-LINE
    PERFORM 5900-WRITE-LINE

    STRING '    "body": ' DELIMITED BY SIZE
           FUNCTION TRIM(WS-UGC-BODY-JSON) DELIMITED BY SIZE
      INTO WS-OUTPUT-LINE
    END-STRING
    PERFORM 5900-WRITE-LINE

    MOVE '  }' TO WS-OUTPUT-LINE
    PERFORM 5900-WRITE-LINE

    MOVE '}' TO WS-OUTPUT-LINE
    PERFORM 5900-WRITE-LINE.

5900-WRITE-LINE.
    *> Un solo intento por linea: si una falla, las siguientes se
    *> saltan (no se sobrescribe el primer motivo de error real).
    IF STEP-OK
        WRITE WS-OUTPUT-RECORD FROM WS-OUTPUT-LINE
        IF WS-OUTPUT-FILE-STATUS NOT = '00'
            MOVE 'N' TO WS-STEP-STATUS
            STRING 'PUB-3002: fallo escribiendo linea de salida (status='
                       DELIMITED BY SIZE
                   WS-OUTPUT-FILE-STATUS DELIMITED BY SIZE
                   ')' DELIMITED BY SIZE
              INTO WS-STEP-ERROR-MSG
            END-STRING
        END-IF
    END-IF.

9000-REPORT-RESULT.
    DISPLAY SPACE
    DISPLAY '--- Resultado de PUBLISH-SIM ---'
    DISPLAY 'content_id      : ' FUNCTION TRIM(WS-CONTENT-ID)
    DISPLAY 'token en config : ' WS-HAS-TOKEN
    DISPLAY 'estado final    : ' FUNCTION TRIM(CONTENT-STATE)
    IF STEP-FAILED
        DISPLAY 'motivo          : ' FUNCTION TRIM(WS-STEP-ERROR-MSG)
    END-IF
    IF STATE-IS-SIMULATED
        DISPLAY 'archivo         : ' FUNCTION TRIM(WS-OUTPUT-PATH)
    END-IF.
