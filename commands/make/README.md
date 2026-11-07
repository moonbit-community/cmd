# make

Run a Make language subset for MoonX.

Development candidate: `cli/make@0.2.5`, using `cli/core@0.9.2`.
Publication and exact-coordinate acceptance are recorded separately in
[latest.json](../../tests/release/latest.json).

```sh
moonx cli/make@0.2.5 [-B] [-k] [-n] [-s] [-j [N]] [-W FILE] [-C DIR] [-f FILE] [VARIABLE=VALUE] [TARGET...]
```

## Supported scope

Build targets with dependencies, variables, includes, conditionals, patterns, automatic variables, exports and parallel recipe chains.

Computed assignment/export names expand once. `=`, `:=`, `::=`, `:::=`, `?=`,
`+=` and `!=` retain their supported flavors and trailing value whitespace.
Recursive export evaluation uses the original environment to break shell-valued
export recursion, while ordinary variable recursion reports an error. `.SHELLSTATUS`
records the actual shell result; `$(shell ...)` and `!=` have distinct trailing
newline rules. Recipe expansion and environment construction are serialized.

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
  special control targets and bare export-all reject. Known unsupported functions
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
moonx cli/make@0.2.5 -n
moonx cli/make@0.2.5 -f build.mk -j 2 all
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0007-language.md)
