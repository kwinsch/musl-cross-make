       IDENTIFICATION DIVISION.
       PROGRAM-ID. xmlparse.
      * COBOL XML PARSE (IBM-dialect subset implemented by gcc 16):
      * needs libgcobol built against the bundled libxml2 -- the
      * without-libxml2 stub reports an exception at runtime, failing
      * this test. Period-terminated because gcc 16.2's scanner omits
      * END-XML from its statement-state keyword table (upstream bug;
      * the grammar itself makes END-XML optional).
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 DOC PIC X(32) VALUE '<a><b>hi</b><!--c--><d>x</d></a>'.
       PROCEDURE DIVISION.
           XML PARSE DOC PROCESSING PROCEDURE EVH
               ON EXCEPTION
                   DISPLAY "XML EXCEPTION"
                   MOVE 8 TO RETURN-CODE
               NOT ON EXCEPTION
                   DISPLAY "XML DONE".
           STOP RUN.
       EVH.
           EVALUATE XML-EVENT
               WHEN 'START-OF-ELEMENT'
                   DISPLAY 'S:' XML-TEXT
               WHEN 'CONTENT-CHARACTERS'
                   DISPLAY 'C:' XML-TEXT
               WHEN 'END-OF-ELEMENT'
                   DISPLAY 'E:' XML-TEXT
               WHEN 'COMMENT'
                   DISPLAY 'K:' XML-TEXT
           END-EVALUATE.
