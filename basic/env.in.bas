
REM ENV_NEW(EO%) -> R%
ENV_NEW:
  REM allocate the data hashmap
  GOSUB HASHMAP
  ET%=R%

  REM set the outer and data pointer
  SZ%=2:GOSUB ALLOC
  Z%(R%,0)=13+16
  Z%(R%,1)=ET%
  Z%(R%+1,0)=13
  Z%(R%+1,1)=EO%
  IF EO%<>-1 THEN Z%(EO%,0)=Z%(EO%,0)+16
  RETURN

REM see RELEASE types.in.bas for environment cleanup

REM ENV_NEW_BINDS(EO%, BI%, EX%) -> R%
ENV_NEW_BINDS:
  GOSUB ENV_NEW
  E%=R%
  REM process bindings
  ENV_NEW_BINDS_LOOP:
    IF Z%(BI%,1)=0 THEN R%=E%:RETURN
    REM get/deref the key from BI%
    R%=BI%+1:GOSUB DEREF_R
    K%=R%

    IF ZS$(Z%(K%,1))="&" THEN GOTO EVAL_NEW_BINDS_VARGS

    EVAL_NEW_BINDS_1x1:
      REM get/deref the key from EX%
      R%=EX%+1:GOSUB DEREF_R
      V%=R%
      REM set the binding in the environment data
      GOSUB ENV_SET
      REM go to next element of BI% and EX%
      BI%=Z%(BI%,1)
      EX%=Z%(EX%,1)
      GOTO ENV_NEW_BINDS_LOOP

    EVAL_NEW_BINDS_VARGS:
      REM get/deref the key from next element of BI%
      BI%=Z%(BI%,1)
      R%=BI%+1:GOSUB DEREF_R
      K%=R%
      REM the value is the remaining list in EX%
      V%=EX%
      REM set the binding in the environment data
      GOSUB ENV_SET
      R%=E%
      RETURN

REM ENV_SET(E%, K%, V%) -> R%
ENV_SET:
  HM%=Z%(E%,1)
  GOSUB ASSOC1
  Z%(E%,1)=R%
  R%=V%
  RETURN

REM ENV_SET_S(E%, K$, V%) -> R%
ENV_SET_S:
  HM%=Z%(E%,1)
  GOSUB ASSOC1_S
  Z%(E%,1)=R%
  R%=V%
  RETURN

REM ENV_FIND(E%, K%) -> R%
REM   Returns environment (R%) containing K%. If found, value found is
REM   in T4%
ENV_FIND:
  EF%=E%
  ENV_FIND_LOOP:
    HM%=Z%(EF%,1)
    REM More efficient to use GET for value (R%) and contains? (T3%)
    GOSUB HASHMAP_GET
    REM if we found it, save value in T4% for ENV_GET
    IF T3%=1 THEN T4%=R%:GOTO ENV_FIND_DONE
    EF%=Z%(EF%+1,1): REM get outer environment
    IF EF%<>-1 THEN GOTO ENV_FIND_LOOP
  ENV_FIND_DONE:
    R%=EF%
    RETURN

REM ENV_GET(E%, K%) -> R%
ENV_GET:
  GOSUB ENV_FIND
  IF R%=-1 THEN R%=0:ER%=1:ER$="'"+ZS$(Z%(K%,1))+"' not found":RETURN
  R%=T4%:GOSUB DEREF_R
  Z%(R%,0)=Z%(R%,0)+16
  RETURN
