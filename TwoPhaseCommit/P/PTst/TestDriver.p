
/*
This machine creates the 2 participants, 1 coordinator, and 2 clients 
*/

machine TestDriverAsync0 {
    start state Init {
        entry {
            var N : int;
            var prim : Primary;
            var participants: seq[Backup];
            var i : int;

            N = 5;
            i = 0;
            while (i < N) {
                participants += (i, new Backup());
                i = i + 1;
            }
            prim = new Primary(participants);

            send prim, eClientRequest, (transactionId = 100, command = "x = 0;");
            send prim, eClientRequest, (transactionId = 101, command = "x = 1;");
        }
    }
}

machine TestDriverSync0 {
    start state Init {
        entry {
            var N : int;
            var system : TwoPhaseSync;

            N = 5;
            system = new TwoPhaseSync(N+1);

            send system, eClientRequest, (transactionId = 100, command = "x = 0;");
            send system, eClientRequest, (transactionId = 101, command = "x = 1;");
        }
    }
}