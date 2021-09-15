// checks that all events are handled correctly and also the local assertions in the P machines.
test TestAsync0[main = TestDriverAsync0]: { TestDriverAsync0, Primary, Backup };

test TestAsync1[main = TestDriverAsync0]: assert AtomicityInvariant in { TestDriverAsync0, Primary, Backup };

test TestSync0[main = TestDriverSync0]: { TestDriverSync0, TwoPhaseSync };

test TestSync1[main = TestDriverSync0]: assert AtomicityInvariant in { TestDriverSync0, TwoPhaseSync };