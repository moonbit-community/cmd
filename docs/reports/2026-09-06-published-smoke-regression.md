# Published smoke regression: `sh -s` positional parameters

Date: 2026-09-06

## Evidence

The native pure-MoonBit release runner executed all 94 selected published
consumer cases against exact MoonX versions. The six other P0 packages at
`0.1.5` and all unaffected packages at `0.1.4` started successfully. The run
completed 93 cases and found one semantic mismatch:

```text
p0-sh-stdin-script: sh -s shell value
expected stdout to contain: value
published cli/sh@0.1.5: stdout missing value
```

The failure is a candidate behavior defect, not an asset or registry failure.
POSIX `sh -s name arg` treats `name` as `$0` and `arg` as `$1`; the published
implementation exposed `name` as `$1` instead.

## Corrective action

The local MoonBit implementation now selects the first operand after `-s` as
the shell name and passes only subsequent operands as positional parameters.
The local regression probe passes:

```text
printf 'echo "$1"\n' | moon run --target native commands/sh -- -s shell value
=> value (status 0)
```

The package version is advanced to `cli/sh@0.1.6`. Its Wasm asset is not yet
published, so the remote published gate must not be run or claimed as passing
until that exact asset is available. No remote push was made from this audit.
