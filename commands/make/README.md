# make

Run a Make language subset for MoonX.

Published: `cli/make@0.2.9`, using `cli/core@0.10.0`.
Three-platform exact-coordinate acceptance and earlier release evidence are recorded in the
[changelog](../../CHANGELOG.md#2026-11-10).

```sh
moonx cli/make@0.2.9 [-B] [-k] [-n] [-s] [-j [N]] [-W FILE] [-C DIR] [-f FILE] [VARIABLE=VALUE] [TARGET...]
```

## Supported scope

Build targets with dependencies, variables, includes, conditionals, patterns, automatic variables, exports and parallel recipe chains.

Version 0.2.9 preserves filesystem traversal in makefile, include,
target and prerequisite paths. After option parsing, requested `-C` directories
resolve in order. On POSIX, missing components fail and `link/..` uses the link
target's parent; Windows retains its native normalization.

Recipe `test -s` uses the final target's metadata, including through symlinks,
without opening it. Missing/cyclic targets are false; unavailable sizes such as
macOS directories are explicit shell errors rather than fabricated zero.

Computed assignment/export names expand once. `=`, `:=`, `::=`, `:::=`, `?=`,
`+=` and `!=` retain their supported flavors and trailing value whitespace.
Recursive export evaluation uses the original environment to break shell-valued
export recursion, while ordinary variable recursion reports an error. `.SHELLSTATUS`
records the actual shell result; `$(shell ...)` and `!=` have distinct trailing
newline rules. Shell syntax/runtime errors record status 2 and retain any output
already written; they do not become fatal make variable errors. Captured output
ends at its first NUL before UTF-8 decoding; invalid UTF-8 before that point is
an explicit profile error. A shell error in a recipe remains subject to its `-`
prefix.

Shell functions and assignments use GNU's default `/bin/sh` argument construction
before running the pure MoonBit interpreter. Literal LF bytes can be part of a
direct argument; the shell path removes raw LF while preserving original
backslash-LF pairs. Single quotes, double quotes, make's `IFS` and an explicit
`SHELL=sh` select different paths. An invocation with no command preserves the
previous `.SHELLSTATUS` and does not construct an exported environment. This
argument handling does not add a host-shell implementation or a full GNU
external-program behavior claim.

Bare `export` enables default export for names beginning with an ASCII letter or
underscore and continuing with ASCII letters, digits or underscores. Bare
`unexport` restores the ordinary environment/command-line defaults; explicit
named export and unexport decisions still win. Named directives create empty
simple variables when the name is undefined, so a later `?=` leaves them empty.
Both directives support assignments and computed names. Assignment modifier
chains use the last export/unexport flag; ordinary name lists remain literal.
Complete assignments are recognized before modifiers: nonblank whitespace may
belong to a variable's name, while bare directives accept GNU's six ASCII
whitespace characters.
`.EXPORT_ALL_VARIABLES` takes effect after all makefiles have been read.

All recipe variable references for a target expand before its first command.
The target's exported environment is then evaluated once, before its first
executed command, and reused for its remaining recipes. Empty recipes, pure `:`
and ordinary `-n` lines do not create that environment; forced/recursive dry-run
recipes do. Make variable recursion errors are fatal even with `-k`, while
actual recipe exit failures retain keep-going behavior. Expansion and environment
construction remain serialized; recipe execution can overlap across targets.

`.SECONDEXPANSION` affects subsequent declarations and expands escaped variables
with target automatic variables before dependency planning. Repeated declarations,
recipe-bearing groups, `$<`, `$^`, `$+` and pattern stems retain the fixed GNU 4.4.1
order. `$?` snapshots distinct changed prerequisites once per target, including
missing targets, phony dependencies, `-B` and virtual `-W` times; later recipes do
not recompute it after changing the target. Inline recipes retain the same rule
ordering and literal recipe `#` bytes. Rule punctuation is recognized outside
balanced variable/function references, so `$(shell ...)` can contain pipes,
colons, semicolons and nested groups. This does not imply its full builtin
rule/function database.

`$(MAKE)` invokes this Wasm command recursively. Exported MAKELEVEL increments
from the invocation level; MAKEFLAGS preserves supported flags, variable flavors,
spaces and dollar transport. Recursive recipes and `+` recipes still run under
`-n`. An existing POSIX `--jobserver-auth=fifo:PATH` shares real tokens, returns
the exact borrowed byte on success/failure/cancellation and preserves the owner's
FIFO. Its implicit slot is distinct from a borrowed token. Descriptor-pipe and
Windows semaphore authentication reject explicitly.

Recipe file tests apply the POSIX trailing-slash directory requirement to every
file predicate and both timestamp-comparison operands. Directory links ending
in a slash select their directory, not the link itself; unsuffixed links retain
their ordinary behavior. See [sh](../sh/README.md) for size-capability boundaries.

## Options

| Option | Description |
| --- | --- |
| `-f, --file FILE` | Select a makefile. |
| `-C DIR` | Change working directory. |
| `-n, --just-print` | Print recipes; recursive and `+` recipes still execute. |
| `-s, --silent` | Suppress recipe echo. |
| `-B, --always-make` | Force rebuilding. |
| `-j [N]` | Run up to N recipe chains; bare -j allows all ready targets. |
| `-k` | Continue independent targets after failures. |
| `-W FILE` | Treat FILE as newly modified. |
| `NAME=VALUE / TARGET` | Set variables / select targets. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Short flags must be separate: use -n -s, not -ns.
- Creating a new FIFO jobserver requires a public FIFO creation API. Without an
  inherited server, local `-jN` is available and recursive children receive `-j1`
  to stay within each occupied parent slot. This is an explicit scheduling limit.
- Descriptor-pipe import, Windows named semaphore inheritance, full GNU builtin
  functions/rules, archive/order-only/target-specific/grouped/double-colon rules,
  other special control targets and override/private assignments reject. Known unsupported functions
  reject before argument expansion, including lazy branches with side effects;
  unknown ordinary variable names keep normal empty-value semantics.
- Explicit `SHELL` assignments accept only literal `sh` or `/bin/sh` as names
  for the built-in pure MoonBit profile; `.SHELLFLAGS` accepts literal `-c`.
  Custom interpreters/flags, computed selectors and selector appends reject;
  inherited empty `.SHELLFLAGS` also rejects before recipe execution.
  An inherited environment SHELL does not select the interpreter and remains
  the child's environment value unless explicitly exported by make.
- Recipes use the supported sh language subset.

## Examples

```sh
moonx cli/make@0.2.9 -n
moonx cli/make@0.2.9 -f build.mk -j 2 all
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0007-language.md)
