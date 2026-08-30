# sleep for moonx

Pause for a number of seconds:

```sh
moonx cli/sleep 2
moonx cli/sleep 0.5
moonx cli/sleep 1m 30s   # arguments are summed
```

NUMBER may be fractional; suffixes `s`, `m`, `h`, `d` scale it. With
multiple arguments, sleeps for their sum.
