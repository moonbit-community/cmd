# sleep for moonx

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Pause for a number of seconds:

```sh
moonx cli/sleep 2
moonx cli/sleep 0.5
moonx cli/sleep 1m 30s   # arguments are summed
```

NUMBER may be fractional; suffixes `s`, `m`, `h`, `d` scale it. With
multiple arguments, sleeps for their sum.

`--help` and `--version` are handled without sleeping.
`--` explicitly ends option parsing before a duration operand.
