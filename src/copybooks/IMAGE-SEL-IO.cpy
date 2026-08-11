      *> Contrato de entrada/salida del agente IMAGE-SEL (design.md 2.4).
      *> Compartido entre CONTENT-PIPELINE.cbl (llamador) y IMAGE-SEL.cbl
      *> (LINKAGE SECTION). Prefijo ISEL- (no IS-) para no confundirse a
      *> simple vista con la palabra reservada IS.
       01  IMAGE-SEL-REQUEST.
           05  ISEL-TRIGGER-TEXT         PIC X(200).

       01  IMAGE-SEL-RESPONSE.
           05  ISEL-IMAGE-REF            PIC X(60).
           05  ISEL-STEP-STATUS          PIC X.
               88  ISEL-STEP-OK                   VALUE 'Y'.
               88  ISEL-STEP-FAILED               VALUE 'N'.
           05  ISEL-STEP-ERROR-MSG       PIC X(100).
