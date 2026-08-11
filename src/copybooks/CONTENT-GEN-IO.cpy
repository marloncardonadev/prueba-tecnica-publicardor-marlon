      *> Contrato de entrada/salida del agente CONTENT-GEN (design.md 2.3).
      *> Compartido entre CONTENT-PIPELINE.cbl (llamador) y CONTENT-GEN.cbl
      *> (LINKAGE SECTION), para que ambos lados siempre tengan el mismo
      *> layout.
       01  CONTENT-GEN-REQUEST.
           05  CG-TRIGGER-TEXT           PIC X(200).
           05  CG-REGEN-COUNT            PIC 9(2).
           05  CG-REGEN-BOOST-ENABLED    PIC X.
               88  CG-BOOST-ENABLED               VALUE 'Y'.

       01  CONTENT-GEN-RESPONSE.
           05  CG-GENERATED-TEXT         PIC X(280).
           05  CG-STEP-STATUS            PIC X.
               88  CG-STEP-OK                     VALUE 'Y'.
               88  CG-STEP-FAILED                 VALUE 'N'.
           05  CG-STEP-ERROR-MSG         PIC X(100).
