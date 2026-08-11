      *> Registro de una entrada del log de auditoria (AUDIT-LOG) del
      *> pipeline de contenido. Un registro = una transicion de estado
      *> (incluida la transicion hacia ERROR). Solo se agrega, nunca se
      *> reescribe ni se borra (ver design.md, seccion 7.3).
      *> Formato libre: incluir con COPY desde un programa compilado con
      *> >>SOURCE FREE.
       01  AUDIT-ENTRY.
           05  AUDIT-SEQ-NUM        PIC 9(9).
           05  AUDIT-CONTENT-ID     PIC X(36).
           05  AUDIT-TIMESTAMP      PIC X(21).
           05  AUDIT-FROM-STATE     PIC X(20).
           05  AUDIT-TO-STATE       PIC X(20).
           05  AUDIT-REASON         PIC X(100).
