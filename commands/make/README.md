# make

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

`cli/make` provides a Make subset implemented in MoonBit. Use `-f/--file FILE`
to select a makefile, `-C DIR` to change its working directory, `-n/--just-print`
for dry runs, `-s/--silent` to suppress recipe echo, and `-B/--always-make` to
force rebuilding. Target operands and `NAME=VALUE` command-line assignments
are accepted.

`include`, `-include`, `sinclude`, command-line variable assignment,
`ifeq`/`ifneq`/`ifdef`/`ifndef`, pattern/static-pattern dependencies, and
automatic variables (`$@`, `$<`, `$^`, `$+`, `$*`, `$@D`, `$@F`, `$<D`, `$<F`)
are supported in the implemented slice. `-j N` schedules independent targets
concurrently with at most N recipe chains, and bare `-j` permits all ready
targets. Shared prerequisites execute once. `-k` continues independent targets
after recipe failures, and `-W`
marks targets depending on the named file out of date. The full GNU built-in
database, jobserver and secondary expansion remain outside the supported
subset. `$(shell ...)` uses the MoonBit shell, converts embedded newlines to
spaces, strips trailing newlines and updates `.SHELLSTATUS`. `-C` supplies the
recipe and shell-function working directory.

Each external command in a recipe is launched through the public MoonBit
process API. The complete Makefile is never forwarded to a host `make`
executable. The remaining
language surface is listed in the
[support record](../../docs/compatibility.md).

Recipes inherit the complete caller environment plus explicitly exported and
command-line make variables. `export NAME[=VALUE]` and `unexport NAME` control
exports; unexported make variables remain local. Bare `export`/`unexport` are
rejected.
Authorization is applied by the caller or host, and locale variables are not
rewritten.

Shell functions receive explicit exports as well. Recursive exported values
that themselves invoke `$(shell ...)` are explicitly rejected; GNU's special
export-recursion fallback remains project interpreter work.
