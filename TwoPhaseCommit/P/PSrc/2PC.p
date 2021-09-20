event eMessage : Message;

event eAlphaMessage: (phase: Phase, from: machine, payload: AlphaPayload);
event eBetaMessage: (phase: Phase, from: machine, payload: BetaPayload);
event eGammaMessage: (phase: Phase, from: machine, payload: GammaPayload);
event eDeltaMessage: (phase: Phase, from: machine, payload: DeltaPayload);

type Command = int;
type Phase = int;
type Mbox = map[Phase, map[Round, seq[Message]]];
type Timestamp = (phase: Phase, round: Round);

event configMessage: Primary;
event eClientRequest: ClientRequest;

type ClientRequest = (transactionId: int, command: string);

type Message = (phase: Phase, from: machine, payload: data);

type AlphaPayload = Command;
type BetaPayload = Vote;
type GammaPayload = Vote;
type DeltaPayload = bool;

enum Round { ALPHA, BETA, GAMMA, DELTA }
enum Vote {COMMIT, ABORT}

machine Primary
{
    var numBackup : int;
    var backups : seq[Backup];
    var localPhase : Phase;
    var mbox : Mbox;
    var commitvotes : map[Phase, int];
    var decision : map[Phase, Vote];

    start state Init 
    {
        defer eClientRequest;

        entry (b: seq[Backup]){
            var participants : seq[machine];

            backups = b;
            numBackup = sizeof(backups);
            sendConfig();

            participants = backups;
            participants += (sizeof(participants), this);

            announce eMonitor_Initialize, participants;

            localPhase = 0; 

            goto Alpha;
        }
    }

    state Alpha 
    {
        defer eAlphaMessage, eBetaMessage, eDeltaMessage, eGammaMessage;

        entry {
            announce eMonitor_TimestampChange, (id=this, ts=(phase=localPhase, round=ALPHA));
        }

        on eClientRequest do (m : ClientRequest) 
        {
            var newcommand : Command;

            initMbox(localPhase);

            Broadcast(eAlphaMessage, (phase = localPhase, from=this, payload = newcommand));
            goto Beta;
        }
    }

    state Beta 
    {
        defer eClientRequest, eAlphaMessage, eGammaMessage, eDeltaMessage;

        entry {
            announce eMonitor_TimestampChange, (id=this, ts=(phase=localPhase, round=BETA));
        }

        on eBetaMessage do (m : Message) 
        {
            announce eMonitor_MessageReceived, (localTs=(phase=localPhase, round=BETA), msgTs=(phase=m.phase, round=BETA));

            if(m.payload == COMMIT)
            {
                commitvotes[m.phase] = commitvotes[m.phase]+1;
            }

            mbox[m.phase][BETA] += (sizeof(mbox[m.phase][BETA]),m);

            //print format("Primary receives eBetaMessage {0} / {1}", sizeof(mbox[m.phase][BETA]), numBackup);

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
            announce eMonitor_TimestampChange, (id=this, ts=(phase=localPhase, round=GAMMA));

            Broadcast(eGammaMessage, (phase = localPhase, from=this, payload = decision[localPhase]));
            goto Delta;
        }
    }

    state Delta 
    {
        defer eClientRequest, eAlphaMessage, eBetaMessage, eGammaMessage;

        entry {
            announce eMonitor_TimestampChange, (id=this, ts=(phase=localPhase, round=DELTA));
        }

        on eDeltaMessage do (m : Message) 
        {
            announce eMonitor_MessageReceived, (localTs=(phase=localPhase, round=DELTA), msgTs=(phase=m.phase, round=DELTA));

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

        return decision;
    }

    fun Broadcast(message: event, payload: Message)
    {
        var i: int; i = 0;
        while (i < numBackup) 
        {
            send backups[i], message, payload;
            i = i + 1;
        }
    }

    fun sendConfig()
    {
        var i : int;
        i = 0;
        while (i < numBackup) 
        {
            send backups[i], configMessage, this;
            i = i + 1;
        }
    }
}

machine Backup
{
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
            announce eMonitor_MessageReceived, (localTs=(phase=localPhase, round=ALPHA), msgTs=(phase=m.phase, round=ALPHA));
            announce eMonitor_TimestampChange, (id=this, ts=(phase=localPhase, round=ALPHA));
            goto Beta;
        }
    }

    state Beta 
    {

        entry 
        {
            var v : Vote;
            
            announce eMonitor_TimestampChange, (id=this, ts=(phase=localPhase, round=BETA));

            v = ABORT;
            if($)
            {
                v = COMMIT;
            }
            send leader, eBetaMessage, (phase = localPhase, from=this, payload = v);
            goto Gamma;
        }

    }

    state Gamma 
    {
        entry {
            announce eMonitor_TimestampChange, (id=this, ts=(phase=localPhase, round=GAMMA));
        }

        on eGammaMessage do (m : Message) 
        {
            announce eMonitor_MessageReceived, (localTs=(phase=localPhase, round=GAMMA), msgTs=(phase=m.phase, round=GAMMA));
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
            announce eMonitor_TimestampChange, (id=this, ts=(phase=localPhase, round=DELTA));

            send leader, eDeltaMessage, (phase = localPhase, from=this, payload=true);
            localPhase = localPhase+1;
            goto Alpha;
        }
    }
}
