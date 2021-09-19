type Messages = map[machine, Mbox];

machine TwoPhaseSync
{
    var numBackups : int;
    var PHASE : Phase;
    var leader : machine;
    var participants : seq[machine];

    var messages : Messages;

    var decision : map[machine,map[Phase, Vote]];

    start state Init 
    {
        entry (p: seq[machine]){

            participants = p;
            numBackups = sizeof(participants)-1;
            
            PHASE = 0; 
            leader = participants[0];
            Init(PHASE);

            announce eMonitor_Initialize, participants;
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
            var id: int;
            i = 0;
            while (i < numBackups) 
            {
                send this, eMessage, (phase = PHASE, from=leader, payload=newcommand);
                i = i + 1;
            }

            // #### UPDATE ######
            ReceiveMessages(ALPHA);
            i = 0;
            while (i < numBackups) 
            {
                id = i+1;
                decision[participants[id]][PHASE] = ABORT;
                if($)
                {
                    decision[participants[id]][PHASE] = COMMIT; 
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
            var id: int;
            i = 0;
            while (i < numBackups) 
            {
                id = i+1;
                send this, eMessage, (phase = PHASE, from=participants[id], payload = decision[participants[id]][PHASE]);
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
            var id : int;
            var finaldecision : Vote;
            
            i = 0;
            while (i < numBackups) 
            {
                send this, eMessage, (phase = PHASE, from=leader, payload = decision[leader][PHASE]);
                i = i + 1;
            }

            // #### UPDATE ######
            ReceiveMessages(GAMMA);

            // Backups record decision
            finaldecision = decision[leader][PHASE];

            i = 0;
            while (i < numBackups) 
            {
                id = i+1;
                decision[participants[id]][PHASE] = finaldecision;
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
            var id: int; 
            // ###### SEND ######
            i = 0;
            while (i < numBackups) 
            {
                id = i+1;
                send this, eMessage, (phase = PHASE, from=participants[id], payload = true);
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
        var i: int; 
        var p: machine;
        
        i = 0;
       
        decision = default(map[machine,map[Phase, Vote]]);
        messages = default(Messages);
        
        while (i < numBackups+1) {
            p = participants[i];
            decision[p] = default(map[Phase, Vote]);
            
            messages[p] = default(Mbox);
            messages[p][PHASE] = default(map[Round, seq[Message]]);

            messages[p][PHASE][ALPHA] = default(seq[Message]);
            messages[p][PHASE][BETA] = default(seq[Message]);
            messages[p][PHASE][GAMMA] = default(seq[Message]);
            messages[p][PHASE][DELTA] = default(seq[Message]);

            i = i+1;
        }
    }

    // In this protocol there always N-1 messages on flight, all-to-one or one-to-all
    fun ReceiveMessages(r: Round)
    {
        var i: int; 
        var p: machine;
        
        i = 1;
        
        while (i <= numBackups) {
            p = participants[i];
            
            receive {
                case eMessage: (m: Message) { 
                    messages[p][PHASE][r] += (sizeof(messages[p][PHASE][r]), m); 
                }
            }
            i = i + 1;
        }
    }

   

}
