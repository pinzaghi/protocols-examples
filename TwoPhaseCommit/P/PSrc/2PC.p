event eMessage : Message;

event eAlphaMessage: (phase: Phase, dst: int, payload: AlphaPayload);
event eBetaMessage: (phase: Phase, dst: int, payload: BetaPayload);
event eGammaMessage: (phase: Phase, dst: int, payload: GammaPayload);
event eDeltaMessage: (phase: Phase, dst: int, payload: DeltaPayload);

type Command = int;
type Phase = int;
type Mbox = map[Phase, map[Round, seq[Message]]];

event configMessage: Primary;
event eClientRequest: ClientRequest;

type ClientRequest = (transactionId: int, command: string);

type Message = (phase: Phase, dst: int, payload: data);

type AlphaPayload = Command;
type BetaPayload = Vote;
type GammaPayload = Vote;
type DeltaPayload = bool;

enum Round { ALPHA, BETA, GAMMA, DELTA }
enum Vote {COMMIT, ABORT}

machine Primary
{
    var N : int;
    var participants : seq[Backup];
    var localPhase : Phase;
    var mbox : Mbox;
    var commitvotes : map[Phase, int];
    var decision : map[Phase, Vote];

    start state Init 
    {
        defer eClientRequest;

        entry (payload: seq[Backup]){
            participants = payload;
            N = sizeof(participants);
            sendConfig();
            announce eMonitor_AtomicityInitialize, N;

            localPhase = 0; 
            goto Alpha;
        }
    }

    state Alpha 
    {
        defer eAlphaMessage, eBetaMessage, eDeltaMessage, eGammaMessage;

        on eClientRequest do (m : ClientRequest) 
        {
            var newcommand : Command;
            initMbox(localPhase);
            Broadcast(eAlphaMessage, (phase = localPhase, dst=0, command = newcommand));
            goto Beta;
        }
    }

    state Beta 
    {
        defer eClientRequest, eAlphaMessage, eGammaMessage, eDeltaMessage;

        on eBetaMessage do (m : Message) 
        {
            if(m.payload == COMMIT)
            {
                commitvotes[m.phase] = commitvotes[m.phase]+1;
            }

            mbox[m.phase][BETA] += (sizeof(mbox[m.phase][BETA]),m);

            if(sizeof(mbox[m.phase][BETA]) == N)
            {
                decision[m.phase] = commit_or_abort(m.phase); 
                goto Gamma;
            }
        }
    }

    state Gamma 
    {
        defer eClientRequest, eAlphaMessage, eBetaMessage, eDeltaMessage;

        entry 
        {
            Broadcast(eGammaMessage, (phase = localPhase, dst=0, payload = decision[localPhase]));
            goto Delta;
        }
    }

    state Delta 
    {
        defer eClientRequest, eAlphaMessage, eBetaMessage, eGammaMessage;

        on eDeltaMessage do (m : Message) 
        {
            mbox[m.phase][DELTA] += (sizeof(mbox[m.phase][DELTA]),m);

            if(sizeof(mbox[m.phase][DELTA]) == N)
            {
                localPhase = localPhase+1;
                goto Alpha;
            }
        }
    }

    fun initMbox(phase: Phase)
    {
        commitvotes[phase] = 0;

        mbox[phase] = default(map[Round, seq[Message]]);

        mbox[phase][ALPHA] = default(seq[Message]);
        mbox[phase][BETA] = default(seq[Message]);
        mbox[phase][GAMMA] = default(seq[Message]);
        mbox[phase][DELTA] = default(seq[Message]);
    }

    fun commit_or_abort(phase: Phase) : Vote
    {
        var decision : Vote;
        decision = ABORT;
        if(commitvotes[phase] == N)
        {
            decision = COMMIT;
        }
        //decision = COMMIT; //BUG
        return decision;
    }

    fun Broadcast(message: event, payload: any)
    {
        var i: int; i = 0;
        while (i < N) 
        {
            send participants[i], message, payload;
            i = i + 1;
        }
    }

    fun sendConfig()
    {
        var i : int;
        i = 0;
        while (i < N) 
        {
            send participants[i], configMessage, this;
            i = i + 1;
        }
    }
}

machine Backup
{
    var participants : seq[Backup];
    var localPhase : Phase;
    var leader : Primary;
    var decision : map[Phase, Vote];

    start state Init 
    {
        entry 
        {
            localPhase = 0;
        }

        on configMessage do (payload: Primary)
        {
            leader = payload;
            goto Alpha;
        }
    }

    state Alpha 
    {
        on eAlphaMessage do (m : Message) 
        {
            goto Beta;
        }
    }

    state Beta 
    {

        entry 
        {
            var v : Vote;
            v = ABORT;
            if($)
            {
                v = COMMIT;
            }
            send leader, eBetaMessage, (phase = localPhase, dst=0, payload = v);
            goto Gamma;
        }

    }

    state Gamma 
    {
        on eGammaMessage do (m : Message) 
        {
            if(m.payload == COMMIT)
            {
                decision[localPhase] = COMMIT;
            } else {
                decision[localPhase] = ABORT;
            }
            goto Delta;
        }
    }

    state Delta {
        entry 
        {
            send leader, eDeltaMessage, (phase = localPhase, dst=0, payload=true);
            localPhase = localPhase+1;
            goto Alpha;
        }
    }
}
