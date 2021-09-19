
/*
This machine creates the 2 participants, 1 coordinator, and 2 clients 
*/

machine TestDriverAsync0 {
    start state Init {
        entry {
            var N : int;
            var prim : Primary;
            var backups: seq[Backup];
            var i : int;

            N = 5;
            i = 0;
            while (i < N) {
                backups += (i, new Backup());
                i = i + 1;
            }
            prim = new Primary(backups);

            send prim, eClientRequest, (transactionId = 100, command = "x = 0;");
            send prim, eClientRequest, (transactionId = 101, command = "x = 1;");
        }
    }
}

machine Participant{
    start state Init {}
}

machine TestDriverSync0 {
    start state Init {
        entry {
            var N : int;
            var system : TwoPhaseSync;
            var i : int;
            var participants: seq[Participant];
            
            N = 6; // 5 Backups + 1 Primary
            i = 0;
            while (i < N) {
                participants += (i, new Participant());
                i = i + 1;
            }
            
            system = new TwoPhaseSync(participants);

            send system, eClientRequest, (transactionId = 100, command = "x = 0;");
            send system, eClientRequest, (transactionId = 101, command = "x = 1;");
        }
    }
}