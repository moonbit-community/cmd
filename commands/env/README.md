# env

Print the environment or execute one command with explicit environment
changes. Supports `-i`/`--ignore-environment` and `-u NAME`/`--unset=NAME`.
The common GNU path also accepts bare `-` as an empty-environment request,
`-0`/`--null` for NUL-separated output, and `-C`/`--chdir` for the child
working directory. `--null` with a child command fails with status 125.
Command execution uses MoonBit's policy-visible process API, never a shell;
the command and every argument are passed as separate argv entries. Because
execution can create a child process, this package is not in the default
policy allow-list.

Native execution starts from the complete parent environment unless `-i` is
present. Wasm execution starts from the restricted policy environment before
applying the requested assignments and removals.
