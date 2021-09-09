event eSVCMessage : tMessage;
event eDVCMessage : tMessage;
event eSVMessage : tMessage;

event eConfig : tConfig;

type tMessage = (label: tRound, view: int, source: Replica);
type tMailbox = map[int, map[tRound, int]];
type tMayority = int;
type tConfig = (peers: seq[Replica], owner: Replica);

enum tRound {
    StartViewChange,
    DoViewChange,
    StartView
}

machine Replica {

    var n : int;
    var f : int;
    var currView : int;
    var peers : seq[Replica];
    var mbox : tMailbox;

    start state Init {

        defer eSVCMessage, eDVCMessage, eSVMessage;
        
	    entry {
            currView = 0;
            InitMailboxView(currView);
		}

        on eConfig do (config : tConfig){
            n = sizeof(config.peers);
            peers = config.peers;

            goto StartViewChange;
        }
	}

    state StartViewChange {

        defer eDVCMessage, eSVMessage;
        ignore eConfig;

        entry {
            Broadcast(eSVCMessage, (label=StartViewChange, view=currView, source=this));
        }

        on eSVCMessage do (message : tMessage) {
            StoreMessage(message);

            if(CountMessages(currView, StartViewChange) > n/2){
                goto DoViewChange;
            }
        }

    }

    state DoViewChange {

        defer eSVCMessage, eSVMessage;
        ignore eConfig;

        entry {
            if(Primary() != this){
                send Primary(), eDVCMessage, (label=DoViewChange, view=currView, source=this);
                goto StartView;
            }
        }

        on eDVCMessage do (message : tMessage) {
            StoreMessage(message);

            if(Primary() == this && CountMessages(currView, DoViewChange) > n/2){
                goto StartView;
            }
        }

    }

    state StartView {

        defer eSVCMessage, eDVCMessage;
        ignore eConfig;

        entry {
            if(Primary() == this){
                Broadcast(eSVMessage, (label=StartView, view=currView, source=this));
                currView = currView+1;
                //goto StartViewChange;
            }
        }

        on eSVMessage do (message : tMessage) {
            StoreMessage(message);

            if(CountMessages(currView, StartView) > 0){
                currView = currView+1;
                goto StartViewChange;
            }
        }

    }

    //helper function to send messages to all replicas
	fun Broadcast(message: event, payload: any)
	{
		var i: int; i = 0;
		while (i < sizeof(peers)) {
			send peers[i], message, payload;
			i = i + 1;
		}
	}

    fun Primary() : Replica
    {
        var i : int; i = currView;
        while(i >= n){
            i = i - n;
        }
        assert i>=0, format("Primary index {0}, n={1}", i, n);
        assert i < sizeof(peers), format("Primary index {0}, n={1}", i, n);
        
        return peers[i];
    }

    fun InitMailboxView(view : int)
    {
        mbox[view] = default(map[tRound, int]);

        mbox[view][StartViewChange] = 0;
        mbox[view][DoViewChange] = 0;
        mbox[view][StartView] = 0;
    }

    fun StoreMessage(message: tMessage)
    {
        var count : int; 

        if(!(message.view in mbox)){
            InitMailboxView(message.view);
        }
        mbox[message.view][message.label] = mbox[message.view][message.label]+1;
        
        
    }

    fun CountMessages(view: int, label: tRound) : int
    {
        var count : int;

        if(view in mbox && label in mbox[view]){
            count = mbox[view][label];
        }else{
            count = 0;
        }       

        return count;

    }

}
