// We would like to assert the atomicity property that if a transaction is committed by the coordinator then it was agreed on by all participants

type Timestamp = (phase: Phase, round: Round);

event eMonitor_TimestampChange : (id: machine, ts: Timestamp);
event eMonitor_Send : (localTs : Timestamp, sentTs: Timestamp);

spec SyncTagInvariant observes eMonitor_Initialize, eMonitor_TimestampChange, eAlphaMessage, eBetaMessage, eGammaMessage, eDeltaMessage
{
    // a map saving the current phase for every participant
    var participants : seq[machine];
    var participantsTimestamp: map[machine, Timestamp];
    var numParticipants: int;
    start state Init {
        on eMonitor_Initialize goto WaitForEvents with (participants: seq[machine]) {
            var i: int; 

            participants = participants;
            numParticipants = sizeof(participants);

            i = 0;
            while (i < numParticipants) 
            {
                participantsTimestamp[participants[i]] = (phase=0, round=ALPHA);
                i = i + 1;
            }
        }
    }

    state WaitForEvents {
        on eMonitor_TimestampChange do (payload: (id: machine, ts: Timestamp)){
            assertStateMonotonicallyIncreasing(payload.id, payload.ts);
        }

        on eAlphaMessage do (m: Message) {
            assertSendWithCurrentTimestamp(m.from, (phase=m.phase, round=ALPHA));
        }

        on eBetaMessage do (m: Message){
            assertSendWithCurrentTimestamp(m.from, (phase=m.phase, round=BETA));
        }

        on eGammaMessage do (m: Message) {
            assertSendWithCurrentTimestamp(m.from, (phase=m.phase, round=GAMMA));
        }

        on eDeltaMessage do (m: Message) {
            assertSendWithCurrentTimestamp(m.from, (phase=m.phase, round=DELTA));
        }
    }

    fun assertSendWithCurrentTimestamp(id : machine, sendTs : Timestamp)
    {
        var currentTs : Timestamp;
        currentTs = participantsTimestamp[id];

        assert (equalTimestamp(currentTs,sendTs)), format ("Send with different timestamp. Timestamp before {0}, new {1}", currentTs, sendTs);

    }

    fun assertStateMonotonicallyIncreasing(id : machine, newTs : Timestamp)
    {
        var currentTs : Timestamp;

        currentTs = participantsTimestamp[id];
        
        assert (geqTimestamp(currentTs,newTs)),
        format ("Participant decreased its local timestamp. Timestamp before {0}, new {1}", currentTs, newTs);

        participantsTimestamp[id] = newTs;
    }

    // Check if ts1 <= ts2
    fun geqTimestamp(ts1 : Timestamp, ts2 : Timestamp) : bool
    {
        return ts2.phase > ts1.phase || (ts2.phase == ts1.phase && roundInt(ts1.round) <= roundInt(ts2.round));
    }

    fun equalTimestamp(ts1 : Timestamp, ts2 : Timestamp) : bool
    {
        return ts2.phase == ts1.phase && roundInt(ts1.round) == roundInt(ts2.round);
    }

    fun roundInt(r : Round) : int
    {
        if(r == ALPHA){
            return 0;
        }else if(r == BETA){
            return 1;
        }else if(r == GAMMA){
            return 2;
        }else{
            return 3;
        }
    }
}