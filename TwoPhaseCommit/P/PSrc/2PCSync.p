type Participant = int;

type Messages = map[Participant, Mbox];

machine TwoPhaseSync
{
    var N : int;
    var PHASE : Phase;
    var leader : int;

    var messages : Messages;

    var decision : map[Participant,map[Phase, Vote]];

    start state Init 
    {
        entry (participants: int){

            N = participants;
            PHASE = 0; 
            leader = 0;
            Init(PHASE);

            announce eMonitor_Initialize, N;
        }

        on eClientRequest do (m : ClientRequest) 
        {
            goto Alpha;
        }
    }

    state Alpha
    {
        entry 
        {
            // ###### SEND ######
            var newcommand : Command;
            // Broadcast from leader to all
            var i: int; 
            i = 0;
            while (i < N) 
            {
                send this, eAlphaMessage, (phase = PHASE, from=leader, dst=i, payload=newcommand);
                i = i + 1;
            }

            // #### UPDATE ######
            ReceiveMessages(ALPHA);
            i = 0;
            while (i < N) 
            {
                decision[i][PHASE] = ABORT;
                if($)
                {
                    decision[i][PHASE] = COMMIT; 
                }
                i = i + 1;
            }

            goto Beta;
        }

    }

    state Beta
    {
        entry 
        {
            // ###### SEND ######
            var i: int; 
            i = 0;
            while (i < N) 
            {
                send this, eBetaMessage, (phase = PHASE, from=i, dst=leader, payload = decision[i][PHASE]);
                i = i + 1;
            }

            // #### UPDATE ######
            ReceiveMessages(BETA);
            
            // Primary decides using votes
            decision[leader][PHASE] = COMMIT;

            i = 0;
            while (i < sizeof(messages[leader][PHASE][BETA])) 
            {
                if(messages[leader][PHASE][BETA][i].payload == ABORT){
                    decision[leader][PHASE] = ABORT;
                }
                i=i+1;
            }

            goto Gamma;
        }

    }

    state Gamma
    {
        entry 
        {
            // ###### SEND ######
            var i: int; 
            var finaldecision : Vote;
            
            i = 0;
            while (i < N) 
            {
                send this, eGammaMessage, (phase = PHASE, from=leader, dst=i, payload = decision[leader][PHASE]);
                i = i + 1;
            }

            // #### UPDATE ######
            ReceiveMessages(GAMMA);

            // Backups record decision
            finaldecision = decision[leader][PHASE];

            i = 0;
            while (i < N) 
            {
                decision[i][PHASE] = finaldecision;
                i = i + 1;
            }

            goto Delta;
        }
    }

    state Delta
    {
        entry 
        {
            var i: int; 
            // ###### SEND ######
            i = 0;
            while (i < N) 
            {
                send this, eDeltaMessage, (phase = PHASE, from=i, dst=leader, payload = true);
                i = i + 1;
            }

            // #### UPDATE ######
            ReceiveMessages(DELTA);

            PHASE = PHASE+1;
            Init(PHASE);

        }

        on eClientRequest do (m : ClientRequest) 
        {
            goto Alpha;
        }

    }


    fun Init(phase: Phase)
    {
        var i: int; i = 0;
       
        decision = default(map[Participant,map[Phase, Vote]]);
        messages = default(Messages);

        while (i < N) {
            decision[i] = default(map[Phase, Vote]);
            
            messages[i] = default(Mbox);
            messages[i][PHASE] = default(map[Round, seq[Message]]);

            messages[i][PHASE][ALPHA] = default(seq[Message]);
            messages[i][PHASE][BETA] = default(seq[Message]);
            messages[i][PHASE][GAMMA] = default(seq[Message]);
            messages[i][PHASE][DELTA] = default(seq[Message]);

            i = i+1;
        }
    }

    // In this protocol there always N messages on flight, all-to-one or one-to-all
    fun ReceiveMessages(r : Round)
    {
        var i: int; i = 0;
        while (i < N) {
            receive {
                case eAlphaMessage: (m: Message) { 
                    messages[m.dst][PHASE][ALPHA] += (sizeof(messages[m.dst][PHASE][ALPHA]), m); 
                }
                case eBetaMessage: (m: Message) { 
                    messages[m.dst][PHASE][BETA] += (sizeof(messages[m.dst][PHASE][BETA]), m); 
                }
                case eGammaMessage: (m: Message) { 
                    messages[m.dst][PHASE][GAMMA] += (sizeof(messages[m.dst][PHASE][GAMMA]), m); 
                }
                case eDeltaMessage: (m: Message) { 
                    messages[m.dst][PHASE][DELTA] += (sizeof(messages[m.dst][PHASE][DELTA]), m); 
                }
            }
            i = i + 1;
        }
    }

}
