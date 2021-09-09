spec Liveness observes eSVMessage, eDVCMessage, eSVCMessage {
    start cold state Init {
        on eSVCMessage goto Waiting; 
        on eDVCMessage goto Waiting; 
    }

    hot state Waiting {
        on eSVMessage goto Init; 
        ignore eSVCMessage;
    }
}

