# 2PC in the P language

## To compile

```
pc -proj:TwoPhaseCommit.pproj
```

## Run model checking with 1000 schedulers
```
pmc netcoreapp3.1/TwoPhaseCommit.dll -m PImplementation.Test0.Execute -i 1000
```
```
pmc netcoreapp3.1/TwoPhaseCommit.dll -m PImplementation.Test1.Execute -i 1000
```
