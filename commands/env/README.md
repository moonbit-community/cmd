# env

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Print the environment or execute one command with explicit environment
changes. Supports `-i`/`--ignore-environment` and `-u NAME`/`--unset=NAME`.
The common GNU path also accepts bare `-` as an empty-environment request,
`-0`/`--null` for NUL-separated output, and `-C`/`--chdir` for the child
working directory. `--null` with a child command fails with status 125.
Command execution uses MoonBit's policy-visible process API, never a shell;
the command and every argument are passed as separate argv entries. Because
execution can create a child process, this package is not in the default
policy allow-list.

The support claims in this README are for the Wasm artifact. Its environment
starts from the policy-provided map before applying requested assignments and
removals; native inheritance is outside this audit record.
