machine Backup
{
    var participants : seq[Backup];
    var localPhase : PhaseType;
    var leader : Primary;
    var decision : map[PhaseType, Vote];

    start state Init {
		entry {
			localPhase = 0;
		}

        on configMessage do (payload: Primary){
            leader = payload;
			goto Alpha;
        }
	}

    state Alpha {

        entry {
		}

		on alphaMessage do (m : AlphaMessageType) {
            goto Beta;
		}

	}

    state Beta {

        entry {
            var v : Vote;
            v = ABORT;
            if($){
                v = COMMIT;
            }
            send leader, betaMessage, (phase = localPhase, vote = v);
            goto Gamma;
		}

    }

    state Gamma {

        on gammaMessage do (m : GammaMessageType) {

            if(m.decision == COMMIT){
                decision[localPhase] = COMMIT;
            }else{
                decision[localPhase] = ABORT;
            }
            goto Delta;
            
		}

    }

    state Delta {

        entry {
            send leader, deltaMessage, (phase = localPhase, ack=true);
            localPhase = localPhase+1;
            goto Alpha;
        }

    }

}
