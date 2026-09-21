# env

This documents version 0.2.0. The [support record](../../docs/compatibility.md)
tracks platform verification and exact-version publication evidence separately.

Print the environment or execute one command with explicit environment
changes. Supports `-i`/`--ignore-environment` and `-u NAME`/`--unset=NAME`.
The common GNU path also accepts bare `-` as an empty-environment request,
`-0`/`--null` for NUL-separated output, and `-C`/`--chdir` for the child
working directory. `--null` with a child command fails with status 125.
Command execution uses MoonBit's policy-visible process API, never a shell;
the command and every argument are passed as separate argv entries. Because
execution can create a child process, the caller or host may require process
authorization. The command itself does not implement an allowlist.

Option/assignment precedence, repeated unsets, `--`, command lookup, and exit
statuses 125 (command setup), 126 (not invokable), and 127 (not found) are
covered by the P2 profile. Non-empty assignment names are passed through even
when they are not shell identifiers, and the first assignment ends option
scanning. `--help` and `--version` return successful output.

Both backends start from the complete environment made available by the host,
then apply the requested removals and assignments. `LANG`, `LC_ALL`, and other
names are neither filtered nor rewritten. Host authorization still applies to
the child working directory and executable.
