# sh

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

`cli/sh` is a MoonBit shell interpreter. The observed Wasm slice includes
simple quoting and variables, pipelines,
redirections, script/stdin selection, and positional arguments.

External commands are policy-visible child requests. The audit did not observe
delegation of a complete script to a host shell.

Wasm child lookup and execution use the host process policy. Native environment
inheritance was not part of this Wasm-only capability audit.

Command substitution currently fails closed with status 2. Conditionals whose
`test` command cannot be resolved by the Wasm host also fail; this is a child
lookup/policy outcome, not host-shell fallback. Other unsupported shell
language constructs fail closed instead of being forwarded to another
interpreter.

When neither `-c` nor a script file is supplied, the shell silently reads its
script from stdin until EOF, as required by the POSIX compatibility path.
`-s` explicitly selects stdin; following operands become `$1`, `$2`, and later
positional parameters while `$0` remains the invocation name. Remaining POSIX language gaps are listed
in the [support record](../../docs/compatibility.md).
