>>SOURCE FREE
*> VOICE-GEN.cbl
*> Agente VoiceAgent (design.md 2.2), extraido de CONTENT-PIPELINE.cbl
*> (antes 3050-VOICE-GEN, inline) como programa independiente, para
*> consistencia con CONTENT-GEN/IMAGE-SEL/VIRALITY-SCORE.
*>
*> v1 (Fase 1 de tasks.md): placeholder honesto. Todavia no existe una
*> hipotesis de voz documentada (tarea F1-03 de tasks.md, pendiente) ni
*> un LLM-PORT real, asi que este agente no tiene ninguna decision que
*> tomar: siempre reporta exito. Antes, la simulacion de "fallo de red"
*> vivia como un flag interno en CONTENT-PIPELINE.cbl porque VOICE-GEN
*> era inline y no habia un limite de CALL que mockear; ahora que existe
*> ese limite, esa simulacion se hace mockeando este CALL desde los
*> tests del orquestador (ver test/CONTENT-PIPELINE.CUT), igual que se
*> hace con los demas agentes.
IDENTIFICATION DIVISION.
PROGRAM-ID. VOICE-GEN.

DATA DIVISION.
LINKAGE SECTION.
COPY "VOICE-GEN-IO.cpy".

PROCEDURE DIVISION USING VOICE-GEN-REQUEST VOICE-GEN-RESPONSE.

0000-VOICE-GEN-MAIN.
    MOVE 'Y' TO VG-STEP-STATUS
    MOVE SPACES TO VG-STEP-ERROR-MSG
    GOBACK.
