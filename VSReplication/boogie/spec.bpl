
type PIDType = int;
type ViewType = int;
type RoundType = int;
type PayloadType;
type MailboxType;

type Field x;

type MessageType = <x>[Field x] x;

const unique viewfield: Field ViewType;
const unique roundfield: Field RoundType;
const unique payloadfield: Field PayloadType;

var current_view: ViewType where current_view >= 0;
var current_round: RoundType where current_round >= 0 && current_round <= 2;

type MessageLog = [ViewType, RoundType] MessageType;
var _msglog: MessageLog;

var _recovery: bool;

// type {:finite} roundl;

// const unique StartView: roundl;
// const unique DoViewChange: roundl extends StartView;
// const unique StartViewChange: roundl extends StartView, DoViewChange;

// axiom ( forall r: roundl :: r == StartViewChange || r == DoViewChange || r == StartView );

const N : int;
axiom 0 < N;

const f : int;
axiom 2*f+1 == N;

const mypid : PIDType;
axiom 0 <= mypid && mypid < N;
axiom ( forall i, j: PIDType :: i != j );

function isLeader(ViewType, PIDType) returns (bool);
    axiom ( forall v: ViewType :: (exists pl: PIDType :: (isLeader(v, pl) && (forall p2: PIDType :: p2 != pl ==> !isLeader(v, p2)))) );

function count_startvc(MailboxType) returns (int);
function count_dovc(MailboxType) returns (int);
function count_sv(MailboxType) returns (int);

function max_view(MailboxType, RoundType) returns (ViewType);

function stale_message_received(MailboxType, ViewType) returns (bool);
function stale_message_pid(MailboxType) returns (PIDType);
    axiom ( forall m: MailboxType :: stale_message_pid(m) != mypid );

function equalMessages(MessageType, MessageType) returns (bool);
    axiom ( forall m1, m2: MessageType :: (equalMessages(m1,m2) <==> (m1[viewfield] == m2[viewfield] && m1[roundfield] == m2[roundfield] && m1[payloadfield] == m2[payloadfield])) );

procedure send(m: MessageType);
    requires    (m[viewfield] == current_view && m[roundfield] == current_round) || 
                (_recovery && ( exists v: ViewType :: v <= current_view && (equalMessages(m, _msglog[v, 0]) || equalMessages(m, _msglog[v, 1]) || equalMessages(m, _msglog[v, 2])) ) );

procedure CreateSVCPayload() returns (p: PayloadType);
    requires current_round == 0;

procedure CreateDVCPayload() returns (p: PayloadType);
    requires current_round == 1;

procedure CreateSVPayload() returns (p: PayloadType);
    requires current_round == 2;

procedure CreateMessage(view: ViewType, round: RoundType, payload: PayloadType) returns (m: MessageType);
    ensures m[viewfield] == view;
    ensures m[roundfield] == round;
    ensures m[payloadfield] == payload;

procedure main()
    modifies current_view, current_round;
    modifies _msglog, _recovery;
    requires current_view == 0 && current_round == 0;
{
    var message: MessageType;

    var payload: PayloadType;
    var mbox: MailboxType;

    var _current_view: ViewType;
    var _current_round: RoundType;

    call payload := CreateSVCPayload();
    call message := CreateMessage(current_view, current_round, payload);
    _msglog[current_view, current_round] := message;
    call send(message);
    
    while(true)
        invariant _current_view < current_view || _current_round < current_round || (current_view == old(current_view) && current_round == old(current_round)) || _recovery;
        invariant ( exists v: ViewType :: v <= current_view && (equalMessages(message, _msglog[v, 0]) || equalMessages(message, _msglog[v, 1]) || equalMessages(message, _msglog[v, 2])) );
    {
        havoc mbox;

        _current_view := current_view;
        _current_round := current_round;
        _recovery := false;
        
        if(isLeader(current_view,mypid) && current_round == 0 && count_startvc(mbox) > f){
            // jump
            if(max_view(mbox, current_round) > current_view){
                current_view := max_view(mbox, current_round);
            }
            current_round := 1;

        }else if(!isLeader(current_view,mypid) && current_round == 0){
            current_round := 1;
            
            call payload := CreateDVCPayload();
            call message := CreateMessage(current_view, current_round, payload);       
            _msglog[current_view, current_round] := message;     
            call send(message);
            
            current_round := 2;
            
        }else if(isLeader(current_view,mypid) && current_round == 1 && count_dovc(mbox) > f){
            // jump
            if(max_view(mbox, current_round) > current_view){
                current_view := max_view(mbox, current_round);
            }

            current_round := 2;

            call payload := CreateSVPayload();
            call message := CreateMessage(current_view, current_round, payload);
            _msglog[current_view, current_round] := message;
            call send(message);
                
            current_view := current_view+1;
            current_round := 0;

            call payload := CreateSVCPayload();
            call message := CreateMessage(current_view, current_round, payload);
            _msglog[current_view, current_round] := message;
            call send(message);
            
        }else if(!isLeader(current_view,mypid) && current_round == 2 && count_sv(mbox) == 1){
            // jump
            if(max_view(mbox, current_round) > current_view){
                current_view := max_view(mbox, current_round);
            }

            current_view := current_view+1;
            current_round := 0;

            call payload := CreateSVCPayload();
            call message := CreateMessage(current_view, current_round, payload);
            _msglog[current_view, current_round] := message;
            call send(message);
            
        }else if(stale_message_received(mbox, current_view)){

            _recovery := true;
            
            if(isLeader(current_view,mypid)){
                if(current_round == 0 || current_round == 1){
                    call send(_msglog[current_view, 0]);
                }else{
                    call send(_msglog[current_view, 2]);
                }
                
            }else{
                if(isLeader(current_view,stale_message_pid(mbox))){
                    call send(_msglog[current_view, 1]);
                }else{
                    call send(_msglog[current_view, 0]);
                }
            }
        
        }else{
            // timeout
            current_round := 0;
            current_view := current_view+1;

            call payload := CreateSVCPayload();
            call message := CreateMessage(current_view, current_round, payload);
            _msglog[current_view, current_round] := message;
            call send(message);
            
        }

    }

}