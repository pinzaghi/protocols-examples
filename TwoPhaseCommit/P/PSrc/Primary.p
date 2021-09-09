event alphaMessage: AlphaMessageType;
event betaMessage: BetaMessageType;
event gammaMessage: GammaMessageType;
event deltaMessage: DeltaMessageType;

event configMessage: Primary;

type CommandType = int;
type PhaseType = int;
type MboxType = map[PhaseType, map[RoundType, int]];
type AlphaMessageType = (phase: PhaseType, command: CommandType);
type BetaMessageType = (phase: PhaseType, vote: Vote);
type GammaMessageType = (phase: PhaseType, decision: Vote);
type DeltaMessageType = (phase: PhaseType, ack: bool);

enum RoundType { ALPHA, BETA, GAMMA, DELTA }
enum Vote {COMMIT, ABORT}

machine Primary
{

    var participants : seq[Backup];
    var localPhase : PhaseType;
    var mbox : MboxType;
    var commitvotes : map[PhaseType, int];
    var decision : map[PhaseType, Vote];

    start state Init {
		entry (payload: seq[Backup]){
			participants = payload;
			localPhase = 0; 
            initMbox(localPhase);
            sendConfig(participants, this);

            announce eMonitor_AtomicityInitialize, sizeof(participants);
			goto Alpha;
		}
	}

    state Alpha {

        entry {
            var newcommand : CommandType;
            Broadcast(alphaMessage, (phase = localPhase, command = newcommand), participants);
            goto Beta;
		}

	}

    state Beta {

        on betaMessage do (m : BetaMessageType) {

            if(!(m.phase in commitvotes)){
                commitvotes[m.phase] = 0;
            }

            if(m.vote == COMMIT){
                commitvotes[m.phase] = commitvotes[m.phase]+1;
            }

            mbox[m.phase][BETA] = mbox[m.phase][BETA] + 1;

            if(mbox[m.phase][BETA] == sizeof(participants))
            {
                decision[m.phase] = commit_or_abort(commitvotes[m.phase], sizeof(participants)); 
                goto Gamma;
            }
		}

    }

    state Gamma {

        entry {
            Broadcast(gammaMessage, (phase = localPhase, decision = decision[localPhase]), participants);
            goto Delta;
		}

    }

    state Delta {

        on deltaMessage do (m : DeltaMessageType) {
            mbox[m.phase][DELTA] = mbox[m.phase][DELTA] + 1;

            if(mbox[m.phase][DELTA] == sizeof(participants))
            {
                localPhase = localPhase+1;
                initMbox(localPhase);
                goto Alpha;
            }
		}

    }

    fun initMbox(phase: PhaseType)
    {
        if(!(phase in mbox)){
            mbox[phase] = default(map[RoundType, int]);
            mbox[phase][ALPHA] = 0;
            mbox[phase][BETA] = 0;
            mbox[phase][GAMMA] = 0;
            mbox[phase][DELTA] = 0;
        }
    }

}

fun Broadcast(message: event, payload: any, participants: seq[Backup])
{
    var i: int; i = 0;
    while (i < sizeof(participants)) {
        send participants[i], message, payload;
        i = i + 1;
    }
}



fun commit_or_abort(commitvotes : int, participants : int) : Vote
{
    var decision : Vote;
    decision = ABORT;
    if(commitvotes == participants){
        decision = COMMIT;
    }
    return decision;
}

fun sendConfig(participants : seq[Backup], leader : Primary){
    var i : int;
    i = 0;
    while (i < sizeof(participants)) {
        send participants[i], configMessage, leader;
        i = i + 1;
    }
}