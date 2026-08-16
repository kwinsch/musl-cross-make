       IDENTIFICATION DIVISION.
       PROGRAM-ID. arith.
      * libgcobol beyond DISPLAY: packed-decimal (COMP-3) arithmetic,
      * PERFORM VARYING, and an edited MOVE with zero suppression.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 I           PIC 9(4)  COMP.
       01 TOTAL       PIC S9(9)V99 COMP-3 VALUE 0.
       01 PRICE       PIC S9(5)V99 COMP-3 VALUE 19.95.
       01 EDITED      PIC Z(6)9.99.
       PROCEDURE DIVISION.
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > 10
               ADD PRICE TO TOTAL
           END-PERFORM.
           MOVE TOTAL TO EDITED.
           DISPLAY "TOTAL=" EDITED.
           COMPUTE TOTAL = TOTAL / 2.
           MOVE TOTAL TO EDITED.
           DISPLAY "HALF=" EDITED.
           STOP RUN.
