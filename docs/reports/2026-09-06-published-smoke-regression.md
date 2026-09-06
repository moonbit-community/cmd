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

The first interpretation of this failure treated `name` as `$0`, but the
pinned POSIX `dash` oracle and the repository's existing compat fixture establish
the contract used here: with `sh -s shell-name value`, `$0` remains the
invocation name (`sh`) and `$1` is `shell-name`. The published implementation
at `0.1.5` matched that oracle; the runner expectation was wrong.

## Corrective action

The local MoonBit implementation retains the oracle-compatible operand handling.
The local regression probe passes:

```text
printf 'printf "%s|%s\\n" "$0" "$1"\n' | moon run --target native commands/sh -- -s shell-name value
=> sh|shell-name (status 0)
```

The package version was advanced to `cli/sh@0.1.7` so the already published
`0.1.6` asset was not overwritten. After publication, the final workflow
(`34015767486`) passed pinned upstream oracle, published differential, all
three published smoke jobs, stress, and the Native/Wasm cross-platform matrix.
