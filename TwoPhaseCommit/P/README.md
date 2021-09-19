# 2PC in the P language

## To compile

```
pc -proj:TwoPhaseCommit.pproj
```

## Run model checking with 1000 schedulers
```
pmc netcoreapp3.1/TwoPhaseCommit.dll -m PImplementation.TestAsyncBasic.Execute -i 1000

pmc netcoreapp3.1/TwoPhaseCommit.dll -m PImplementation.TestAsyncAtomicity.Execute -i 1000

pmc netcoreapp3.1/TwoPhaseCommit.dll -m PImplementation.TestAsyncSyncTag.Execute -i 1000

pmc netcoreapp3.1/TwoPhaseCommit.dll -m PImplementation.TestSyncBasic.Execute -i 1000

```
