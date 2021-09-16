// We would like to assert the atomicity property that if a transaction is committed by the coordinator then it was agreed on by all participants

type Timestamp = (phase: Phase, round: Round);

spec SyncTagInvariant observes eAlphaMessage, eBetaMessage, eGammaMessage, eDeltaMessage, eMonitor_Initialize
{
    // a map saving the current phase for every participant
    var participantsTimestamp: map[Participant, Timestamp];
    var numParticipants: int;
    start state Init {
        on eMonitor_Initialize goto WaitForEvents with (n: int) {
            var i: int; 

            numParticipants = n;

            i = 0;
            while (i < numParticipants) 
            {
                participantsTimestamp[i] = (phase=0, round=ALPHA);
                i = i + 1;
            }
        }
    }

    state WaitForEvents {
        on eAlphaMessage do (m: Message){
            assertMonotonicallyIncreasingSend(m, ALPHA);
        }

        on eBetaMessage do (m: Message){
            assertMonotonicallyIncreasingSend(m, BETA);
        }

        on eGammaMessage do (m: Message){
            assertMonotonicallyIncreasingSend(m, GAMMA);
        }

        on eDeltaMessage do (m: Message){
            assertMonotonicallyIncreasingSend(m, DELTA);
        }
    }

    fun assertMonotonicallyIncreasingSend(m : Message, r : Round)
    {
        var currentTs : Timestamp;
        var sendTs : Timestamp;

        currentTs = participantsTimestamp[m.from];
        sendTs = (phase=m.phase, round=r);
        
        assert (geqTimestamp(currentTs,sendTs)),
        format ("Participant sent a message tagged with a past timestamp. Sent {0}, last send {1}", sendTs, currentTs);

        participantsTimestamp[m.from] = sendTs;
    }

    // Check if ts1 <= ts2
    fun geqTimestamp(ts1 : Timestamp, ts2 : Timestamp) : bool
    {
        return ts2.phase > ts1.phase || (ts2.phase == ts1.phase && roundInt(ts1.round) <= roundInt(ts2.round));
    }

    fun roundInt(r : Round) : int
    {
        if(r == ALPHA){
            return 1;
        }else if(r == BETA){
            return 2;
        }else if(r == GAMMA){
            return 3;
        }else{
            return 4;
        }
    }
}