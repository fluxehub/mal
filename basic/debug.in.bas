REM CHECK_FREE_LIST() -> P2
CHECK_FREE_LIST:
  REM start and accumulator
  P1=ZK
  P2=0
  CHECK_FREE_LIST_LOOP:
    IF P1>=ZI THEN GOTO CHECK_FREE_LIST_DONE
    IF (Z%(P1)AND 31)<>15 THEN P2=-1:GOTO CHECK_FREE_LIST_DONE
    P2=P2+(Z%(P1)AND-32)/32
    P1=Z%(P1+1)
    GOTO CHECK_FREE_LIST_LOOP
  CHECK_FREE_LIST_DONE:
    IF P2=-1 THEN PRINT "corrupt free list at "+STR$(P1)
    RETURN

PR_MEMORY_SUMMARY_SMALL:
  #cbm P0=FRE(0)

  GOSUB CHECK_FREE_LIST
  #cbm PRINT "Free:"+STR$(FRE(0))+", ";
  PRINT "Values:"+STR$(ZI-1-P2)+", Emptys:";
  FOR I=0 TO 4 STEP 2:GOSUB PR_MEMORY_SUMMARY_SMALL_1:NEXT I
  FOR I=6 TO 12 STEP 3:GOSUB PR_MEMORY_SUMMARY_SMALL_1:NEXT I
  PRINT
  RETURN
  PR_MEMORY_SUMMARY_SMALL_1:
    PRINT STR$(INT(Z%(I)/32))+",";
    RETURN

REM REM COUNT_STRINGS() -> P2
REM COUNT_STRINGS:
REM   P1=0
REM   P2=0
REM   COUNT_STRINGS_LOOP:
REM     IF P1>S-1 THEN RETURN
REM     IF S%(P1)>0 THEN P2=P2+1
REM     P1=P1+1
REM     GOTO COUNT_STRINGS_LOOP
REM 
REM PR_MEMORY_SUMMARY:
REM   #cbm P0=FRE(0)
REM 
REM   PRINT
REM   #cbm PRINT "Free (FRE)   :"+STR$(P0)
REM   GOSUB CHECK_FREE_LIST: REM get count in P2
REM   PRINT "Values (Z%)  :"+STR$(ZI-1-P2)+" /"+STR$(Z1)
REM   REM PRINT "               max:"+STR$(ZI-1);
REM   REM PRINT ", freed:"+STR$(P2)+", after repl_env:"+STR$(ZT)
REM   GOSUB COUNT_STRINGS
REM   PRINT "Strings (S$) :"+STR$(P2)+" /"+STR$(Z2)
REM   #qbasic PRINT "Stack (X%)   :"+STR$(X+1)+" /"+STR$(Z3)
REM   #cbm PRINT "Stack        :"+STR$(X+2-Z3)+" / 1920"
REM   RETURN
REM 
REM #cbm PR_MEMORY_MAP:
REM   #cbm PRINT
REM   #cbm P1=PEEK(43)+PEEK(44)*256
REM   #cbm P2=PEEK(45)+PEEK(46)*256
REM   #cbm P3=PEEK(47)+PEEK(48)*256
REM   #cbm P4=PEEK(49)+PEEK(50)*256
REM   #cbm P5=PEEK(51)+PEEK(52)*256
REM   #cbm P6=PEEK(53)+PEEK(54)*256
REM   #cbm P7=PEEK(55)+PEEK(56)*256
REM   #cbm PRINT "BASIC beg.   :"STR$(P1)
REM   #cbm PRINT "Variable beg.:"STR$(P2)
REM   #cbm PRINT "Array beg.   :"STR$(P3)
REM   #cbm PRINT "Array end    :"STR$(P4)
REM   #cbm PRINT "String beg.  :"STR$(P5)
REM   #cbm PRINT "String cur.  :"STR$(P6)
REM   #cbm PRINT "BASIC end    :"STR$(P7)
REM   #cbm PRINT
REM   #cbm PRINT "Program Code :"STR$(P2-P1)
REM   #cbm PRINT "Variables    :"STR$(P3-P2)
REM   #cbm PRINT "Arrays       :"STR$(P4-P3)
REM   #cbm PRINT "String Heap  :"STR$(P7-P5)
REM   #cbm RETURN
REM 
REM REM PR_MEMORY_VALUE(I) -> J:
REM REM   - I is memory value to print
REM REM   - I is returned as last byte of value printed
REM REM   - J is returned as type
REM PR_MEMORY_VALUE:
REM   J=Z%(I)AND 31
REM   P3=Z%(I+1)
REM   PRINT " "+STR$(I)+": type:"+STR$(J);
REM   IF J<>15 THEN PRINT ", refs:"+STR$((Z%(I)-J)/32);
REM   IF J=15 THEN PRINT ", size:"+STR$((Z%(I)AND-32)/32);
REM   PRINT ", ["+STR$(Z%(I));+" |"+STR$(P3);
REM   IF J<6 OR J=9 OR J=12 OR J=15 THEN PRINT " | --- | --- ]";:GOTO PR_MEM_SKIP
REM   PRINT " |"+STR$(Z%(I+2));
REM   IF J=6 OR J=7 OR J=13 OR J=14 THEN PRINT " | --- ]";:GOTO PR_MEM_SKIP
REM   PRINT " |"+STR$(Z%(I+3))+" ]";
REM   PR_MEM_SKIP:
REM   PRINT " >> ";
REM   ON J+1 GOTO PR_ENTRY_NIL,PR_ENTRY_BOOL,PR_ENTRY_INT,PR_ENTRY_FLOAT,PR_ENTRY_STR,PR_ENTRY_SYM,PR_ENTRY_LIST,PR_ENTRY_VECTOR,PR_ENTRY_HASH_MAP,PR_ENTRY_FN,PR_ENTRY_MALFN,PR_ENTRY_MAC,PR_ENTRY_ATOM,PR_ENTRY_ENV,PR_ENTRY_META,PR_ENTRY_FREE
REM   PRINT "Unknown type:"+STR$(J):END
REM 
REM   PR_ENTRY_NIL:
REM     PRINT "nil"
REM     I=I+1
REM     RETURN
REM   PR_ENTRY_BOOL:
REM     IF P3=0 THEN PRINT "false"
REM     IF P3=1 THEN PRINT "true"
REM     I=I+1
REM     RETURN
REM   PR_ENTRY_INT:
REM   PR_ENTRY_FLOAT:
REM     PRINT STR$(P3)
REM     I=I+1
REM     RETURN
REM   PR_ENTRY_STR:
REM     PRINT "'"+S$(P3)+"'"
REM     I=I+1
REM     RETURN
REM   PR_ENTRY_SYM:
REM     PRINT S$(P3)
REM     I=I+1
REM     RETURN
REM   PR_ENTRY_LIST:
REM     I=I+2
REM     IF I<16 THEN PRINT "()":RETURN
REM     PRINT "(..."+STR$(Z%(I))+" ...)"
REM     RETURN
REM   PR_ENTRY_VECTOR:
REM     I=I+2
REM     IF I<16 THEN PRINT "[]":RETURN
REM     PRINT "[..."+STR$(Z%(I))+" ...]"
REM     RETURN
REM   PR_ENTRY_HASH_MAP:
REM     I=I+3
REM     IF I<16 THEN PRINT "{}":RETURN
REM     IF J=8 THEN PRINT "{... key:"+STR$(Z%(I-1))+", val:"+STR$(Z%(I))+" ...}"
REM     RETURN
REM   PR_ENTRY_FN:
REM     PRINT "#<fn"+STR$(P3)+">"
REM     I=I+1
REM     RETURN
REM   PR_ENTRY_MALFN:
REM   PR_ENTRY_MAC:
REM     IF I=11 THEN PRINT "MACRO ";
REM     PRINT "(fn* param:"+STR$(Z%(I))+", env:"+STR$(Z%(I+1))+")"
REM     I=I+3
REM     RETURN
REM   PR_ENTRY_ATOM:
REM     PRINT "(atom val:"+STR$(P3)+")"
REM     I=I+1
REM     RETURN
REM   PR_ENTRY_ENV:
REM     PRINT "#<env hm:"+STR$(P3)+", outer:"+STR$(Z%(I+2))+">"
REM     I=I+2
REM     RETURN
REM   PR_ENTRY_META:
REM     PRINT "#<meta obj:"+STR$(P3)+", meta:"+STR$(Z%(I+2))+">"
REM     I=I+2
REM     RETURN
REM   PR_ENTRY_FREE:
REM     PRINT "FREE next:"+STR$(P3);
REM     IF I=ZK THEN PRINT " (free list start)";
REM     PRINT
REM     I=I-1+(Z%(I)AND-32)/32
REM     RETURN
REM 
REM REM PR_OBJECT(P1) -> nil
REM PR_OBJECT:
REM   RD=0
REM 
REM   IF P1=-1 THEN PRINT "  "+STR$(-1)+": ---":RETURN
REM   RD=RD+1
REM   Q=P1:GOSUB PUSH_Q
REM 
REM   PR_OBJ_LOOP:
REM     IF RD=0 THEN RETURN
REM     RD=RD-1
REM 
REM     GOSUB PEEK_Q:I=Q
REM     REM IF I<15 THEN GOSUB POP_Q:GOTO PR_OBJ_LOOP
REM     GOSUB PR_MEMORY_VALUE
REM     REM J holds type now
REM     GOSUB POP_Q:I=Q
REM 
REM     IF J<6 OR J=9 THEN GOTO PR_OBJ_LOOP: REM no contained references
REM     REM reference in first position
REM     IF Z%(I+1)<>0 THEN RD=RD+1:Q=Z%(I+1):GOSUB PUSH_Q
REM     IF J=12 OR J=15 THEN PR_OBJ_LOOP: REM no more reference
REM     REM reference in second position
REM     IF Z%(I+2)<>0 THEN RD=RD+1:Q=Z%(I+2):GOSUB PUSH_Q
REM     IF J=6 OR J=7 OR J=13 OR J=14 THEN PR_OBJ_LOOP: REM no more references
REM     IF Z%(I+3)<>0 THEN RD=RD+1:Q=Z%(I+3):GOSUB PUSH_Q
REM     GOTO PR_OBJ_LOOP
REM 
REM REM PR_MEMORY(P1, P2) -> nil
REM PR_MEMORY:
REM   IF P2<P1 THEN P2=ZI-1
REM   PRINT "Values (Z%)"+STR$(P1)+" ->"+STR$(P2);
REM   PRINT " (ZI: "+STR$(ZI)+", ZK: "+STR$(ZK)+"):"
REM   IF P2<P1 THEN PRINT "  ---":GOTO PR_MEMORY_AFTER_VALUES
REM   I=P1
REM   PR_MEMORY_VALUE_LOOP:
REM     IF I>P2 THEN GOTO PR_MEMORY_AFTER_VALUES
REM     GOSUB PR_MEMORY_VALUE
REM     I=I+1
REM     GOTO PR_MEMORY_VALUE_LOOP
REM   PR_MEMORY_AFTER_VALUES:
REM   PRINT "S$ String Memory (S: "+STR$(S)+"):"
REM   IF S<=0 THEN PRINT "  ---":GOTO PR_MEMORY_SKIP_STRINGS
REM   FOR I=0 TO S-1
REM     PRINT " "+STR$(I)+": '"+S$(I)+"'"
REM     NEXT I
REM   PR_MEMORY_SKIP_STRINGS:
REM   PRINT "X% Stack Memory (X: "+STR$(X)+"):"
REM #cbm  IF X<Z3 THEN PRINT "  ---":GOTO PR_MEMORY_SKIP_STACK
REM #cbm  FOR I=Z3 TO X
REM #cbm    PRINT " "+STR$(I)+": "+STR$(PEEK(X)+PEEK(X+1)*256)
REM #cbm    NEXT I
REM #qbasic  IF X<0 THEN PRINT "  ---":GOTO PR_MEMORY_SKIP_STACK
REM #qbasic  FOR I=0 TO X
REM #qbasic    #qbasic PRINT " "+STR$(I)+": "+STR$(X%(I))
REM #qbasic    NEXT I
REM   PR_MEMORY_SKIP_STACK:
REM   RETURN
REM 
