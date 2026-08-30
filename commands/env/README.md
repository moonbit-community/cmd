# env

Print the environment or execute one command with explicit environment
changes. Supports `-i`/`--ignore-environment` and `-u NAME`/`--unset=NAME`.
Command execution uses MoonBit's policy-visible process API, never a shell;
the command and every argument are passed as separate argv entries. Because
execution can create a child process, this package is not in the default
policy allow-list.
