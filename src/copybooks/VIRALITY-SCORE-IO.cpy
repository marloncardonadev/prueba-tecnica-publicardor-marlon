      *> Contrato de entrada/salida del agente VIRALITY-SCORE
      *> (design.md 2.5). Compartido entre CONTENT-PIPELINE.cbl
      *> (llamador) y VIRALITY-SCORE.cbl (LINKAGE SECTION).
       01  VIRALITY-SCORE-REQUEST.
           05  VS-GENERATED-TEXT         PIC X(280).

       01  VIRALITY-SCORE-RESPONSE.
           05  VS-VIRALITY-LEVEL         PIC X(6).
               88  VS-LEVEL-LOW                   VALUE 'LOW'.
               88  VS-LEVEL-MEDIUM                VALUE 'MEDIUM'.
               88  VS-LEVEL-HIGH                   VALUE 'HIGH'.
           05  VS-STEP-STATUS            PIC X.
               88  VS-STEP-OK                     VALUE 'Y'.
               88  VS-STEP-FAILED                 VALUE 'N'.
           05  VS-STEP-ERROR-MSG         PIC X(100).
