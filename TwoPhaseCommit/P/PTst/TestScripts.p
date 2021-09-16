// checks that all events are handled correctly and also the local assertions in the P machines.
test TestAsyncBasic[main = TestDriverAsync0]: { TestDriverAsync0, Primary, Backup };

test TestAsyncAtomicity[main = TestDriverAsync0]: assert AtomicityInvariant in { TestDriverAsync0, Primary, Backup };

test TestAsyncSyncTag[main = TestDriverAsync0]: assert SyncTagInvariant in { TestDriverAsync0, Primary, Backup };

test TestSyncBasic[main = TestDriverSync0]: { TestDriverSync0, TwoPhaseSync };

test TestSyncAtomicity[main = TestDriverSync0]: assert AtomicityInvariant in { TestDriverSync0, TwoPhaseSync };

test TestSyncSyncTag[main = TestDriverSync0]: assert SyncTagInvariant in { TestDriverSync0, TwoPhaseSync };