
/*
This machine creates the 2 participants, 1 coordinator, and 2 clients 
*/
machine TestDriver0 {
    start state Init {
        entry {
            var prim : Primary;
            var participants: seq[Backup];
            var i : int;
            while (i < 2) {
                participants += (i, new Backup());
                i = i + 1;
            }
            prim = new Primary(participants);
        }
    }
}
