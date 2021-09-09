------------------------------ MODULE TwoPhaseSync ------------------------------
CONSTANT RM       \* The set of participating resource managers

VARIABLES
  rmState,       \* $rmState[rm]$ is the state of resource manager RM.
  tmState,       \* The state of the transaction manager.
  step,
  msgs  

Message ==
  [type : {"Prepared"}, rm : RM]  \cup  [type : {"Commit", "Abort"}]
  
TPTypeOK ==  
  /\ rmState \in [RM -> {"working", "prepared", "committed", "aborted"}]
  /\ tmState \in {"init", "committed", "aborted"}
  /\ globalStep \in {"alphaSend", "alphaUpdate", "betaSend", "betaUpdate", 
                "gammaSend", "gammaUpdate", "deltaSend", "deltaUpdate"}
  /\ msgs \subseteq Message
  
TPInit ==   
  /\ rmState = [rm \in RM |-> "working"]
  /\ tmState = "init"
  /\ tmPrepared   = {}
  /\ msgs = {}
-----------------------------------------------------------------------------
TMRcvPrepared(rm) ==
  /\ tmState = "init"
  /\ step = "alphaSend"
  /\ [type |-> "Prepared", rm |-> rm] \in msgs
  /\ tmPrepared' = tmPrepared \cup {rm}
  /\ UNCHANGED <<rmState, tmState, msgs>>
  
TPNext == 


-----------------------------------------------------------------------------
TPSpec == TPInit /\ [][TPNext]_<<rmState, tmState, tmPrepared, msgs>>

THEOREM TPSpec => []TPTypeOK
-----------------------------------------------------------------------------

TC == INSTANCE TCommit 

THEOREM TPSpec => TC!TCSpec

=============================================================================
\* Modification History
\* Last modified Mon Aug 30 17:06:08 CEST 2021 by inzaghi
\* Created Fri Aug 27 11:21:41 CEST 2021 by inzaghi
