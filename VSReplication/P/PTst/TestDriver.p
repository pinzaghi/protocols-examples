machine TestDriver0 {
	start state Init {
		entry {
            var peers : seq[Replica];

			peers += (0, new Replica());
            peers += (1, new Replica());
            peers += (2, new Replica());

            send peers[0], eConfig, (peers=peers, owner=peers[0]);
            send peers[1], eConfig, (peers=peers, owner=peers[1]);
            send peers[2], eConfig, (peers=peers, owner=peers[2]);
		}
	}
}
