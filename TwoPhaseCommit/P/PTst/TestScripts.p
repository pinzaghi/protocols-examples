// checks that all events are handled correctly and also the local assertions in the P machines.
test Test0[main = TestDriver0]: { TestDriver0, Primary, Backup};

test Test1[main = TestDriver0]: assert AtomicityInvariant in { TestDriver0, Primary, Backup};