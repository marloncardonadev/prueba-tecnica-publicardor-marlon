      *> Contrato de entrada/salida del agente VOICE-GEN (design.md 2.2,
      *> VoiceAgent). Compartido entre CONTENT-PIPELINE.cbl (llamador) y
      *> VOICE-GEN.cbl (LINKAGE SECTION).
      *>
      *> v1: sin hipotesis de voz todavia definida (tarea F1-03 de
      *> tasks.md, pendiente), asi que el contrato es minimo. Se deja
      *> VG-TRIGGER-TEXT en el request por simetria con los demas
      *> agentes y para cuando exista una regla real que dependa del
      *> tema (hoy no se usa).
       01  VOICE-GEN-REQUEST.
           05  VG-TRIGGER-TEXT           PIC X(200).

       01  VOICE-GEN-RESPONSE.
           05  VG-STEP-STATUS            PIC X.
               88  VG-STEP-OK                     VALUE 'Y'.
               88  VG-STEP-FAILED                 VALUE 'N'.
           05  VG-STEP-ERROR-MSG         PIC X(100).
