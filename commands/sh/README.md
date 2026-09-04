# sh

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

`cli/sh` is a MoonBit shell interpreter. The observed Wasm slice includes
simple quoting and variables, pipelines, redirections (including
here-documents), command substitution, conditionals, case/pattern matching,
loops, functions and `return`, grouping/subshells, positional parameters
including `${#name}` and `shift`, and `set -e/-u` status rules.

External commands are policy-visible child requests. The audit did not observe
delegation of a complete script to a host shell.

Wasm child lookup and execution use the host process policy. Native environment
inheritance was not part of this Wasm-only capability audit.

Unsupported shell language constructs fail closed instead of being forwarded to
another interpreter. The interpreter never delegates a complete script to a
host shell.

When neither `-c` nor a script file is supplied, the shell silently reads its
script from stdin until EOF, as required by the POSIX compatibility path.
`-s` explicitly selects stdin; following operands become `$1`, `$2`, and later
positional parameters while `$0` remains the invocation name. Remaining POSIX language gaps are listed
in the [support record](../../docs/compatibility.md).
