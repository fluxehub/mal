REM APPLY should really be in types.in.bas but it is here because it
REM calls DO_TCO_FUNCTION so it will cause syntax errors for steps1-3
REM if it is in types.in.bas because there are unresolved labels.

REM APPLY(F, AR) -> R
REM   - restores E
REM   - call using GOTO and with return label/address on the stack
SUB APPLY
  REM if metadata, get the actual object
  IF (Z%(F,0)AND 31)>=16 THEN F=Z%(F,1)

  IF (Z%(F,0)AND 31)=9 THEN GOTO APPLY_FUNCTION
  IF (Z%(F,0)AND 31)=10 THEN GOTO APPLY_MAL_FUNCTION
  IF (Z%(F,0)AND 31)=11 THEN GOTO APPLY_MAL_FUNCTION

  APPLY_FUNCTION:
    REM regular function
    IF Z%(F,1)<60 THEN GOSUB DO_FUNCTION:GOTO APPLY_DONE
    REM for recur functions (apply, map, swap!), use GOTO
    IF Z%(F,1)>60 THEN CALL DO_TCO_FUNCTION
    GOTO APPLY_DONE

  APPLY_MAL_FUNCTION:
    Q=E:GOSUB PUSH_Q: REM save the current environment

    REM create new environ using env and params stored in the
    REM function and bind the params to the apply arguments
    C=Z%(F+1,1):A=Z%(F+1,0):B=AR:GOSUB ENV_NEW_BINDS

    A=Z%(F,1):E=R:CALL EVAL

    AY=E:GOSUB RELEASE: REM release the new environment

    GOSUB POP_Q:E=Q: REM pop/restore the saved environment

  APPLY_DONE:
END SUB


REM DO_TCO_FUNCTION(F, AR)
SUB DO_TCO_FUNCTION
  G=Z%(F,1)

  REM Get argument values
  R=AR+1:GOSUB DEREF_R:AA=R
  R=Z%(AR,1)+1:GOSUB DEREF_R:AB=R

  ON G-60 GOTO DO_APPLY,DO_MAP,DO_SWAP_BANG

  DO_APPLY:
    F=AA
    AR=Z%(AR,1)
    B=AR:GOSUB COUNT:R4=R

    A=Z%(AR+1,1)
    REM no intermediate args, but not a list, so convert it first
    IF R4<=1 AND (Z%(A,0)AND 31)<>6 THEN T=6:GOSUB FORCE_SEQ_TYPE:GOTO DO_APPLY_2
    REM no intermediate args, just call APPLY directly
    IF R4<=1 THEN GOTO DO_APPLY_1

    REM prepend intermediate args to final args element
    A=AR:B=0:C=R4-1:GOSUB SLICE
    REM release the terminator of new list (we skip over it)
    AY=Z%(R6,1):GOSUB RELEASE
    REM attach end of slice to final args element
    Z%(R6,1)=Z%(A+1,1)
    Z%(Z%(A+1,1),0)=Z%(Z%(A+1,1),0)+32

    GOTO DO_APPLY_2

    DO_APPLY_1:
      AR=A:CALL APPLY

      GOTO DO_TCO_FUNCTION_DONE

    DO_APPLY_2:
      GOSUB PUSH_R: REM push/save new args for release

      AR=R:CALL APPLY

      REM pop/release new args
      GOSUB POP_Q:AY=Q
      GOSUB RELEASE
      GOTO DO_TCO_FUNCTION_DONE

  DO_MAP:
    F=AA

    REM first result list element
    T=6:L=0:N=0:GOSUB ALLOC

    REM push future return val, prior entry, F and AB
    GOSUB PUSH_R
    Q=0:GOSUB PUSH_Q
    Q=F:GOSUB PUSH_Q
    Q=AB:GOSUB PUSH_Q

    DO_MAP_LOOP:
      REM set previous to current if not the first element
      GOSUB PEEK_Q_2
      IF Q<>0 THEN Z%(Q,1)=R
      REM update previous reference to current
      Q=R:GOSUB PUT_Q_2

      IF Z%(AB,1)=0 THEN GOTO DO_MAP_DONE

      REM create argument list for apply call
      Z%(3,0)=Z%(3,0)+32
      REM inc ref cnt of referred argument
      T=6:L=3:N=Z%(AB+1,1):GOSUB ALLOC

      REM push argument list
      GOSUB PUSH_R

      AR=R:CALL APPLY

      REM pop apply args and release them
      GOSUB POP_Q:AY=Q
      GOSUB RELEASE

      REM set the result value
      GOSUB PEEK_Q_2
      Z%(Q+1,1)=R

      IF ER<>-2 THEN GOTO DO_MAP_DONE

      REM restore F
      GOSUB PEEK_Q_1:F=Q

      REM update AB to next source element
      GOSUB PEEK_Q
      Q=Z%(Q,1)
      AB=Q
      GOSUB PUT_Q

      REM allocate next element
      T=6:L=0:N=0:GOSUB ALLOC

      GOTO DO_MAP_LOOP

    DO_MAP_DONE:
      Q=3:GOSUB PEEK_Q_Q: REM get return val
      REM if no error, set the return val
      IF ER=-2 THEN R=Q
      REM otherwise, free the return value and return nil
      IF ER<>-2 THEN R=0:AY=Q:GOSUB RELEASE

      REM pop everything off stack
      GOSUB POP_Q:GOSUB POP_Q:GOSUB POP_Q:GOSUB POP_Q
      GOTO DO_TCO_FUNCTION_DONE


  DO_SWAP_BANG:
    F=AB

    REM add atom to front of the args list
    T=6:L=Z%(Z%(AR,1),1):N=Z%(AA,1):GOSUB ALLOC: REM cons
    AR=R

    REM push args for release after
    Q=AR:GOSUB PUSH_Q

    REM push atom
    Q=AA:GOSUB PUSH_Q

    CALL APPLY

    REM pop atom
    GOSUB POP_Q:AA=Q

    REM pop and release args
    GOSUB POP_Q:AY=Q
    GOSUB RELEASE

    REM use reset to update the value
    AB=R:GOSUB DO_RESET_BANG

    REM but decrease ref cnt of return by 1 (not sure why)
    AY=R:GOSUB RELEASE

    GOTO DO_TCO_FUNCTION_DONE

  DO_TCO_FUNCTION_DONE:
END SUB


REM DO_FUNCTION(F, AR)
DO_FUNCTION:
  REM Get the function number
  G=Z%(F,1)

  REM Get argument values
  R=AR+1:GOSUB DEREF_R:AA=R
  R=Z%(AR,1)+1:GOSUB DEREF_R:AB=R

  REM Switch on the function number
  IF G>59 THEN ER=-1:E$="unknown function"+STR$(G):RETURN
  ON INT(G/10)+1 GOTO DO_1_9,DO_10_19,DO_20_29,DO_30_39,DO_40_49,DO_50_59

  DO_1_9:
  ON G GOTO DO_EQUAL_Q,DO_THROW,DO_NIL_Q,DO_TRUE_Q,DO_FALSE_Q,DO_STRING_Q,DO_SYMBOL,DO_SYMBOL_Q,DO_KEYWORD
  DO_10_19:
  ON G-9 GOTO DO_KEYWORD_Q,DO_PR_STR,DO_STR,DO_PRN,DO_PRINTLN,DO_READ_STRING,DO_READLINE,DO_SLURP,DO_LT,DO_LTE
  DO_20_29:
  ON G-19 GOTO DO_GT,DO_GTE,DO_ADD,DO_SUB,DO_MULT,DO_DIV,DO_TIME_MS,DO_LIST,DO_LIST_Q,DO_VECTOR
  DO_30_39:
  ON G-29 GOTO DO_VECTOR_Q,DO_HASH_MAP,DO_MAP_Q,DO_ASSOC,DO_THROW,DO_GET,DO_CONTAINS,DO_KEYS,DO_VALS,DO_SEQUENTIAL_Q
  DO_40_49:
  ON G-39 GOTO DO_CONS,DO_CONCAT,DO_NTH,DO_FIRST,DO_REST,DO_EMPTY_Q,DO_COUNT,DO_CONJ,DO_SEQ,DO_WITH_META
  DO_50_59:
  ON G-49 GOTO DO_META,DO_ATOM,DO_ATOM_Q,DO_DEREF,DO_RESET_BANG,DO_EVAL,DO_READ_FILE,DO_PR_MEMORY_SUMMARY

  DO_EQUAL_Q:
    A=AA:B=AB:GOSUB EQUAL_Q
    R=R+1
    RETURN
  DO_THROW:
    ER=AA
    Z%(ER,0)=Z%(ER,0)+32
    R=0
    RETURN
  DO_NIL_Q:
    R=1
    IF AA=0 THEN R=2
    RETURN
  DO_TRUE_Q:
    R=1
    IF AA=2 THEN R=2
    RETURN
  DO_FALSE_Q:
    R=1
    IF AA=1 THEN R=2
    RETURN
  DO_STRING_Q:
    R=1
    IF (Z%(AA,0)AND 31)<>4 THEN RETURN
    IF MID$(S$(Z%(AA,1)),1,1)=CHR$(127) THEN RETURN
    R=2
    RETURN
  DO_SYMBOL:
    B$=S$(Z%(AA,1))
    T=5:GOSUB STRING
    RETURN
  DO_SYMBOL_Q:
    R=1
    IF (Z%(AA,0)AND 31)=5 THEN R=2
    RETURN
  DO_KEYWORD:
    B$=S$(Z%(AA,1))
    IF MID$(B$,1,1)<>CHR$(127) THEN B$=CHR$(127)+B$
    T=4:GOSUB STRING
    RETURN
  DO_KEYWORD_Q:
    R=1
    IF (Z%(AA,0)AND 31)<>4 THEN RETURN
    IF MID$(S$(Z%(AA,1)),1,1)<>CHR$(127) THEN RETURN
    R=2
    RETURN

  DO_PR_STR:
    AZ=AR:B=1:SE$=" ":GOSUB PR_STR_SEQ
    B$=R$:T=4:GOSUB STRING
    RETURN
  DO_STR:
    AZ=AR:B=0:SE$="":GOSUB PR_STR_SEQ
    B$=R$:T=4:GOSUB STRING
    RETURN
  DO_PRN:
    AZ=AR:B=1:SE$=" ":GOSUB PR_STR_SEQ
    PRINT R$
    R=0
    RETURN
  DO_PRINTLN:
    AZ=AR:B=0:SE$=" ":GOSUB PR_STR_SEQ
    PRINT R$
    R=0
    RETURN
  DO_READ_STRING:
    A$=S$(Z%(AA,1))
    GOSUB READ_STR
    RETURN
  DO_READLINE:
    A$=S$(Z%(AA,1)):GOSUB READLINE
    IF EZ=1 THEN EZ=0:R=0:RETURN
    B$=R$:T=4:GOSUB STRING
    RETURN
  DO_SLURP:
    R$=""
    #cbm OPEN 1,8,0,S$(Z%(AA,1))
    #qbasic A$=S$(Z%(AA,1))
    #qbasic IF NOT _FILEEXISTS(A$) THEN ER=-1:E$="File not found":RETURN
    #qbasic OPEN A$ FOR INPUT AS #1
    DO_SLURP_LOOP:
      A$=""
      #cbm GET#1,A$
      #qbasic A$=INPUT$(1,1)
      #qbasic IF EOF(1) THEN RS=1:A$=A$+CHR$(10)+")":GOTO DO_SLURP_DONE
      IF ASC(A$)=10 THEN R$=R$+CHR$(13)
      IF (ASC(A$)<>10) AND (A$<>"") THEN R$=R$+A$
      #cbm IF (ST AND 64) THEN GOTO DO_SLURP_DONE
      #cbm IF (ST AND 255) THEN ER=-1:E$="File read error "+STR$(ST):RETURN
      GOTO DO_SLURP_LOOP
    DO_SLURP_DONE:
      CLOSE 1
      B$=R$:T=4:GOSUB STRING
      RETURN

  DO_LT:
    R=1
    IF Z%(AA,1)<Z%(AB,1) THEN R=2
    RETURN
  DO_LTE:
    R=1
    IF Z%(AA,1)<=Z%(AB,1) THEN R=2
    RETURN
  DO_GT:
    R=1
    IF Z%(AA,1)>Z%(AB,1) THEN R=2
    RETURN
  DO_GTE:
    R=1
    IF Z%(AA,1)>=Z%(AB,1) THEN R=2
    RETURN

  DO_ADD:
    T=2:L=Z%(AA,1)+Z%(AB,1):GOSUB ALLOC
    RETURN
  DO_SUB:
    T=2:L=Z%(AA,1)-Z%(AB,1):GOSUB ALLOC
    RETURN
  DO_MULT:
    T=2:L=Z%(AA,1)*Z%(AB,1):GOSUB ALLOC
    RETURN
  DO_DIV:
    T=2:L=Z%(AA,1)/Z%(AB,1):GOSUB ALLOC
    RETURN
  DO_TIME_MS:
    T=2:L=INT((TI-BT)*16.667):GOSUB ALLOC
    RETURN

  DO_LIST:
    R=AR
    Z%(R,0)=Z%(R,0)+32
    RETURN
  DO_LIST_Q:
    A=AA:GOSUB LIST_Q
    R=R+1: REM map to mal false/true
    RETURN
  DO_VECTOR:
    A=AR:T=7:GOSUB FORCE_SEQ_TYPE
    RETURN
  DO_VECTOR_Q:
    R=1
    IF (Z%(AA,0)AND 31)=7 THEN R=2
    RETURN
  DO_HASH_MAP:
    A=AR:T=8:GOSUB FORCE_SEQ_TYPE
    RETURN
  DO_MAP_Q:
    R=1
    IF (Z%(AA,0)AND 31)=8 THEN R=2
    RETURN
  DO_ASSOC:
    H=AA
    AR=Z%(AR,1)
    DO_ASSOC_LOOP:
      R=AR+1:GOSUB DEREF_R:K=R
      R=Z%(AR,1)+1:GOSUB DEREF_R:C=R
      Z%(H,0)=Z%(H,0)+32
      GOSUB ASSOC1:H=R
      AR=Z%(Z%(AR,1),1)
      IF AR=0 OR Z%(AR,1)=0 THEN RETURN
      GOTO DO_ASSOC_LOOP
  DO_GET:
    IF AA=0 THEN R=0:RETURN
    H=AA:K=AB:GOSUB HASHMAP_GET
    GOSUB DEREF_R
    Z%(R,0)=Z%(R,0)+32
    RETURN
  DO_CONTAINS:
    H=AA:K=AB:GOSUB HASHMAP_CONTAINS
    R=R+1
    RETURN
  DO_KEYS:
    GOTO DO_KEYS_VALS
  DO_VALS:
    AA=Z%(AA,1)
  DO_KEYS_VALS:
    REM first result list element
    T=6:L=0:N=0:GOSUB ALLOC:T2=R

    DO_KEYS_VALS_LOOP:
      IF AA=0 OR Z%(AA,1)=0 THEN R=T2:RETURN

      REM copy the value
      T1=Z%(AA+1,1)
      REM inc ref cnt of referred argument
      Z%(T1,0)=Z%(T1,0)+32
      Z%(R+1,1)=T1

      T1=R: REM save previous
      REM allocate next element
      T=6:L=0:N=0:GOSUB ALLOC
      REM point previous element to this one
      Z%(T1,1)=R

      IF Z%(Z%(AA,1),1)=0 THEN R=T2:RETURN

      AA=Z%(Z%(AA,1),1)

      GOTO DO_KEYS_VALS_LOOP

  DO_SEQUENTIAL_Q:
    R=1
    IF (Z%(AA,0)AND 31)=6 OR (Z%(AA,0)AND 31)=7 THEN R=2
    RETURN
  DO_CONS:
    T=6:L=AB:N=AA:GOSUB ALLOC
    RETURN
  DO_CONCAT:
    REM if empty arguments, return empty list
    IF Z%(AR,1)=0 THEN R=3:Z%(R,0)=Z%(R,0)+32:RETURN

    REM single argument
    IF Z%(Z%(AR,1),1)<>0 THEN GOTO DO_CONCAT_MULT
      REM force to list type
      A=AA:T=6:GOSUB FORCE_SEQ_TYPE
      RETURN

    REM multiple arguments
    DO_CONCAT_MULT:
      REM TODO: something other than direct X access?
      CZ=X: REM save current stack position
      REM push arguments onto the stack
      DO_CONCAT_STACK:
        R=AR+1:GOSUB DEREF_R
        GOSUB PUSH_R: REM push sequence
        AR=Z%(AR,1)
        IF Z%(AR,1)<>0 THEN GOTO DO_CONCAT_STACK

    REM pop last argument as our seq to prepend to
    GOSUB POP_Q:AB=Q
    REM last arg/seq is not copied so we need to inc ref to it
    Z%(AB,0)=Z%(AB,0)+32
    DO_CONCAT_LOOP:
      IF X=CZ THEN R=AB:RETURN
      GOSUB POP_Q:AA=Q: REM pop off next seq to prepend
      IF Z%(AA,1)=0 THEN GOTO DO_CONCAT_LOOP: REM skip empty seqs
      A=AA:B=0:C=-1:GOSUB SLICE

      REM release the terminator of new list (we skip over it)
      AY=Z%(R6,1):GOSUB RELEASE
      REM attach new list element before terminator (last actual
      REM element to the next sequence
      Z%(R6,1)=AB

      AB=R
      GOTO DO_CONCAT_LOOP
  DO_NTH:
    B=AA:GOSUB COUNT
    B=Z%(AB,1)
    IF R<=B THEN R=0:ER=-1:E$="nth: index out of range":RETURN
    DO_NTH_LOOP:
      IF B=0 THEN GOTO DO_NTH_DONE
      B=B-1
      AA=Z%(AA,1)
      GOTO DO_NTH_LOOP
    DO_NTH_DONE:
      R=Z%(AA+1,1)
      Z%(R,0)=Z%(R,0)+32
      RETURN
  DO_FIRST:
    IF AA=0 THEN R=0:RETURN
    IF Z%(AA,1)=0 THEN R=0
    IF Z%(AA,1)<>0 THEN R=AA+1:GOSUB DEREF_R
    IF R<>0 THEN Z%(R,0)=Z%(R,0)+32
    RETURN
  DO_REST:
    IF AA=0 THEN R=3:Z%(R,0)=Z%(R,0)+32:RETURN
    IF Z%(AA,1)=0 THEN A=AA
    IF Z%(AA,1)<>0 THEN A=Z%(AA,1)
    T=6:GOSUB FORCE_SEQ_TYPE
    RETURN
  DO_EMPTY_Q:
    R=1
    IF Z%(AA,1)=0 THEN R=2
    RETURN
  DO_COUNT:
    B=AA:GOSUB COUNT
    T=2:L=R:GOSUB ALLOC
    RETURN
  DO_CONJ:
    R=0
    RETURN
  DO_SEQ:
    R=0
    RETURN

  DO_WITH_META:
    T=Z%(AA,0)AND 31
    REM remove existing metadata first
    IF T>=16 THEN AA=Z%(AA,1):GOTO DO_WITH_META
    T=T+16:L=AA:N=AB:GOSUB ALLOC
    RETURN
  DO_META:
    IF (Z%(AA,0)AND 31)<16 THEN R=0:RETURN
    R=Z%(AA+1,1)
    Z%(R,0)=Z%(R,0)+32
    RETURN
  DO_ATOM:
    T=12:L=AA:GOSUB ALLOC
    RETURN
  DO_ATOM_Q:
    R=1
    IF (Z%(AA,0)AND 31)=12 THEN R=2
    RETURN
  DO_DEREF:
    R=Z%(AA,1):GOSUB DEREF_R
    Z%(R,0)=Z%(R,0)+32
    RETURN
  DO_RESET_BANG:
    R=AB
    REM release current value
    AY=Z%(AA,1):GOSUB RELEASE
    REM inc ref by 2 for atom ownership and since we are returning it
    Z%(R,0)=Z%(R,0)+64
    REM update value
    Z%(AA,1)=R
    RETURN

  REM DO_PR_MEMORY:
  REM   P1=ZT:P2=-1:GOSUB PR_MEMORY
  REM   RETURN
  DO_PR_MEMORY_SUMMARY:
    GOSUB PR_MEMORY_SUMMARY
    RETURN

  DO_EVAL:
    Q=E:GOSUB PUSH_Q: REM push/save environment
    A=AA:E=D:CALL EVAL
    GOSUB POP_Q:E=Q
    RETURN

  DO_READ_FILE:
    A$=S$(Z%(AA,1))
    GOSUB READ_FILE
    RETURN

INIT_CORE_SET_FUNCTION:
  GOSUB NATIVE_FUNCTION
  C=R:GOSUB ENV_SET_S
  RETURN

REM INIT_CORE_NS(E)
INIT_CORE_NS:
  REM create the environment mapping
  REM must match DO_FUNCTION mappings

  K$="=":A=1:GOSUB INIT_CORE_SET_FUNCTION
  K$="throw":A=2:GOSUB INIT_CORE_SET_FUNCTION
  K$="nil?":A=3:GOSUB INIT_CORE_SET_FUNCTION
  K$="true?":A=4:GOSUB INIT_CORE_SET_FUNCTION
  K$="false?":A=5:GOSUB INIT_CORE_SET_FUNCTION
  K$="string?":A=6:GOSUB INIT_CORE_SET_FUNCTION
  K$="symbol":A=7:GOSUB INIT_CORE_SET_FUNCTION
  K$="symbol?":A=8:GOSUB INIT_CORE_SET_FUNCTION
  K$="keyword":A=9:GOSUB INIT_CORE_SET_FUNCTION
  K$="keyword?":A=10:GOSUB INIT_CORE_SET_FUNCTION

  K$="pr-str":A=11:GOSUB INIT_CORE_SET_FUNCTION
  K$="str":A=12:GOSUB INIT_CORE_SET_FUNCTION
  K$="prn":A=13:GOSUB INIT_CORE_SET_FUNCTION
  K$="println":A=14:GOSUB INIT_CORE_SET_FUNCTION
  K$="read-string":A=15:GOSUB INIT_CORE_SET_FUNCTION
  K$="readline":A=16:GOSUB INIT_CORE_SET_FUNCTION
  K$="slurp":A=17:GOSUB INIT_CORE_SET_FUNCTION

  K$="<":A=18:GOSUB INIT_CORE_SET_FUNCTION
  K$="<=":A=19:GOSUB INIT_CORE_SET_FUNCTION
  K$=">":A=20:GOSUB INIT_CORE_SET_FUNCTION
  K$=">=":A=21:GOSUB INIT_CORE_SET_FUNCTION
  K$="+":A=22:GOSUB INIT_CORE_SET_FUNCTION
  K$="-":A=23:GOSUB INIT_CORE_SET_FUNCTION
  K$="*":A=24:GOSUB INIT_CORE_SET_FUNCTION
  K$="/":A=25:GOSUB INIT_CORE_SET_FUNCTION
  K$="time-ms":A=26:GOSUB INIT_CORE_SET_FUNCTION

  K$="list":A=27:GOSUB INIT_CORE_SET_FUNCTION
  K$="list?":A=28:GOSUB INIT_CORE_SET_FUNCTION
  K$="vector":A=29:GOSUB INIT_CORE_SET_FUNCTION
  K$="vector?":A=30:GOSUB INIT_CORE_SET_FUNCTION
  K$="hash-map":A=31:GOSUB INIT_CORE_SET_FUNCTION
  K$="map?":A=32:GOSUB INIT_CORE_SET_FUNCTION
  K$="assoc":A=33:GOSUB INIT_CORE_SET_FUNCTION
  K$="dissoc":A=34:GOSUB INIT_CORE_SET_FUNCTION
  K$="get":A=35:GOSUB INIT_CORE_SET_FUNCTION
  K$="contains?":A=36:GOSUB INIT_CORE_SET_FUNCTION
  K$="keys":A=37:GOSUB INIT_CORE_SET_FUNCTION
  K$="vals":A=38:GOSUB INIT_CORE_SET_FUNCTION

  K$="sequential?":A=39:GOSUB INIT_CORE_SET_FUNCTION
  K$="cons":A=40:GOSUB INIT_CORE_SET_FUNCTION
  K$="concat":A=41:GOSUB INIT_CORE_SET_FUNCTION
  K$="nth":A=42:GOSUB INIT_CORE_SET_FUNCTION
  K$="first":A=43:GOSUB INIT_CORE_SET_FUNCTION
  K$="rest":A=44:GOSUB INIT_CORE_SET_FUNCTION
  K$="empty?":A=45:GOSUB INIT_CORE_SET_FUNCTION
  K$="count":A=46:GOSUB INIT_CORE_SET_FUNCTION

  K$="conj":A=47:GOSUB INIT_CORE_SET_FUNCTION
  K$="seq":A=48:GOSUB INIT_CORE_SET_FUNCTION

  K$="with-meta":A=49:GOSUB INIT_CORE_SET_FUNCTION
  K$="meta":A=50:GOSUB INIT_CORE_SET_FUNCTION
  K$="atom":A=51:GOSUB INIT_CORE_SET_FUNCTION
  K$="atom?":A=52:GOSUB INIT_CORE_SET_FUNCTION
  K$="deref":A=53:GOSUB INIT_CORE_SET_FUNCTION
  K$="reset!":A=54:GOSUB INIT_CORE_SET_FUNCTION

  K$="eval":A=55:GOSUB INIT_CORE_SET_FUNCTION
  K$="read-file":A=56:GOSUB INIT_CORE_SET_FUNCTION
  K$="pr-memory-summary":A=57:GOSUB INIT_CORE_SET_FUNCTION

  REM these are in DO_TCO_FUNCTION
  K$="apply":A=61:GOSUB INIT_CORE_SET_FUNCTION
  K$="map":A=62:GOSUB INIT_CORE_SET_FUNCTION
  K$="swap!":A=63:GOSUB INIT_CORE_SET_FUNCTION

  RETURN
