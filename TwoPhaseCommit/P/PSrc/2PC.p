event eMessage : Message;

event eAlphaMessage: (phase: Phase, from: Participant, dst: Participant, payload: AlphaPayload);
event eBetaMessage: (phase: Phase, from: Participant, dst: Participant, payload: BetaPayload);
event eGammaMessage: (phase: Phase, from: Participant, dst: Participant, payload: GammaPayload);
event eDeltaMessage: (phase: Phase, from: Participant, dst: Participant, payload: DeltaPayload);

type Command = int;
type Phase = int;
type Mbox = map[Phase, map[Round, seq[Message]]];

event configMessage: Primary;
event eClientRequest: ClientRequest;

type ClientRequest = (transactionId: int, command: string);

type Message = (phase: Phase, from: Participant, dst: Participant, payload: data);

type AlphaPayload = Command;
type BetaPayload = Vote;
type GammaPayload = Vote;
type DeltaPayload = bool;

enum Round { ALPHA, BETA, GAMMA, DELTA }
enum Vote {COMMIT, ABORT}

machine Primary
{
    var numBackup : int;
    var ID : Participant;
    var participants : seq[Backup];
    var localPhase : Phase;
    var mbox : Mbox;
    var commitvotes : map[Phase, int];
    var decision : map[Phase, Vote];

    start state Init 
    {
        defer eClientRequest;

        entry (payload: (id: Participant, participants: seq[Backup])){
            participants = payload.participants;
            ID = payload.id;
            numBackup = sizeof(payload.participants);
            sendConfig();

            announce eMonitor_Initialize, numBackup+1;

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
            Broadcast(eAlphaMessage, (phase = localPhase, from=ID, dst=0, payload = newcommand));
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

            if(sizeof(mbox[m.phase][BETA]) == numBackup)
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
            Broadcast(eGammaMessage, (phase = localPhase, from=ID, dst=0, payload = decision[localPhase]));
            goto Delta;
        }
    }

    state Delta 
    {
        defer eClientRequest, eAlphaMessage, eBetaMessage, eGammaMessage;

        on eDeltaMessage do (m : Message) 
        {
            mbox[m.phase][DELTA] += (sizeof(mbox[m.phase][DELTA]),m);

            if(sizeof(mbox[m.phase][DELTA]) == numBackup)
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
        if(commitvotes[phase] == numBackup)
        {
            decision = COMMIT;
        }
        //decision = COMMIT; //BUG
        return decision;
    }

    fun Broadcast(message: event, payload: Message)
    {
        var i: int; i = 1;
        while (i < numBackup) 
        {
            payload.dst = i;
            send participants[i], message, payload;
            i = i + 1;
        }
    }

    fun sendConfig()
    {
        var i : int;
        i = 0;
        while (i < numBackup) 
        {
            send participants[i], configMessage, this;
            i = i + 1;
        }
    }
}

machine Backup
{
    var participants : seq[Backup];
    var ID : Participant;
    var localPhase : Phase;
    var leader : Primary;
    var decision : map[Phase, Vote];

    start state Init 
    {
        entry (id: Participant)
        {
            ID = id;
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
            send leader, eBetaMessage, (phase = localPhase, from=ID, dst=0, payload = v);
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
            send leader, eDeltaMessage, (phase = localPhase, from=ID, dst=0, payload=true);
            localPhase = localPhase+1;
            goto Alpha;
        }
    }
}
