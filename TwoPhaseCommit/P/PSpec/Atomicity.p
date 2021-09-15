// event used to initialize the AtomicityInvariant spec monitor
event eMonitor_AtomicityInitialize: int;

// We would like to assert the atomicity property that if a transaction is committed by the coordinator then it was agreed on by all participants
spec AtomicityInvariant observes eBetaMessage, eGammaMessage, eMonitor_AtomicityInitialize
{
    // a map from transaction id to a map from responses status to number of participants with that response
    var participantsResponse: map[Phase, map[data, int]];
    var numParticipants: int;
    start state Init {
        on eMonitor_AtomicityInitialize goto WaitForEvents with (n: int) {
            numParticipants = n;
        }
    }

    state WaitForEvents {
        on eBetaMessage do (m: Message){
            var phase: Phase;
            phase = m.phase;

            if(!(phase in participantsResponse))
            {
                participantsResponse[phase] = default(map[data, int]);
                participantsResponse[phase][COMMIT] = 0;
                participantsResponse[phase][ABORT] = 0;
            }
            participantsResponse[phase][m.payload] = participantsResponse[phase][m.payload] + 1;
        }

        on eGammaMessage do (m: Message) {
            assert (m.phase in participantsResponse),
            format ("Write transaction was responded to the client without receiving any responses from the participants!");
            if(m.payload == COMMIT)
            {
                assert participantsResponse[m.phase][COMMIT] == numParticipants,
                format ("Write transaction was responded as committed before receiving success from all participants. ") +
                format ("participants sent success: {0}, participants sent error: {1}", participantsResponse[m.phase][COMMIT],
                participantsResponse[m.phase][ABORT]);
            }
            else if(m.payload == ABORT)
            {
                assert participantsResponse[m.phase][ABORT] > 0,
                format ("Write transaction was responded as failed before receiving error from atleast one participant. ") +
                format ("participants sent success: {0}, participants sent error: {1}", participantsResponse[m.phase][COMMIT],
                participantsResponse[m.phase][ABORT]);
            }
        }
    }
}