>>SOURCE FREE
*> CONTENT-GEN.cbl
*> Agente ContentAgent (design.md 2.3), extraido de CONTENT-PIPELINE.cbl
*> (antes 3100-GENERATE-CONTENT) para que exista como programa
*> independiente, llamado por CALL dinamico (design.md 4, factory via
*> CALL) en vez de vivir inline en el orquestador.
*>
*> v1 (Fase 1 de tasks.md): plantilla local, sin LLM-PORT real. Recibe
*> el numero de intento de regeneracion (CG-REGEN-COUNT) y un gancho de
*> prueba (CG-REGEN-BOOST-ENABLED) para decidir si un reintento usa una
*> plantilla con mas terminos del territorio COBOL/legacy — eso es lo
*> que le da a FLAG_FOR_REGENERATION (design.md 2.6) una oportunidad
*> real de cambiar la senal de viralidad calculada despues por
*> VIRALITY-SCORE, en vez de repetir el mismo texto sin motivo.
IDENTIFICATION DIVISION.
PROGRAM-ID. CONTENT-GEN.

DATA DIVISION.
LINKAGE SECTION.
COPY "CONTENT-GEN-IO.cpy".

PROCEDURE DIVISION USING CONTENT-GEN-REQUEST CONTENT-GEN-RESPONSE.

0000-CONTENT-GEN-MAIN.
    MOVE SPACES TO CG-GENERATED-TEXT
    IF CG-REGEN-COUNT = 0 OR NOT CG-BOOST-ENABLED
        STRING FUNCTION TRIM(CG-TRIGGER-TEXT) DELIMITED BY SIZE
               '. Si tu shop de mainframe sigue discutiendo esto en reuniones, ya perdio el primer semestre.'
                   DELIMITED BY SIZE
          INTO CG-GENERATED-TEXT
          ON OVERFLOW
              MOVE 'N' TO CG-STEP-STATUS
              MOVE 'El texto generado supera el limite de un post corto' TO CG-STEP-ERROR-MSG
          NOT ON OVERFLOW
              MOVE 'Y' TO CG-STEP-STATUS
        END-STRING
    ELSE
        STRING FUNCTION TRIM(CG-TRIGGER-TEXT) DELIMITED BY SIZE
               '. Modernizar COBOL con IA no es reescribir: es entender el legacy antes de tocarlo.'
                   DELIMITED BY SIZE
          INTO CG-GENERATED-TEXT
          ON OVERFLOW
              MOVE 'N' TO CG-STEP-STATUS
              MOVE 'El texto generado supera el limite de un post corto' TO CG-STEP-ERROR-MSG
          NOT ON OVERFLOW
              MOVE 'Y' TO CG-STEP-STATUS
        END-STRING
    END-IF
    GOBACK.
