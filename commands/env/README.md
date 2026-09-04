# env

Observed native/Wasm profile (2026-09-04): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable unified-runner results and exclusions.

Print the environment or execute one command with explicit environment
changes. Supports `-i`/`--ignore-environment` and `-u NAME`/`--unset=NAME`.
The common GNU path also accepts bare `-` as an empty-environment request,
`-0`/`--null` for NUL-separated output, and `-C`/`--chdir` for the child
working directory. `--null` with a child command fails with status 125.
Command execution uses MoonBit's policy-visible process API, never a shell;
the command and every argument are passed as separate argv entries. Because
execution can create a child process, this package is not in the default
policy allow-list.

Option/assignment precedence, repeated unsets, `--`, command lookup, and exit
statuses 125 (command setup), 126 (not invokable), and 127 (not found) are
covered by the P2 profile. Non-empty assignment names are passed through even
when they are not shell identifiers, and the first assignment ends option
scanning. `--help` remains an explicit status-125 rejection; it is not
advertised as a successful help path.

The support claims in this README are for the Wasm artifact. Its environment
starts from the policy-provided map before applying requested removals and
assignments. Both the requested child working directory and executable must be
authorized by the host policy.
