# Phase 5 Process and Language Compatibility Spike

Date: 2026-09-03

## Decision

The delivered process slice remains pure MoonBit. `env`, `xargs`, `sh`, and
`make` launch only explicitly parsed child commands through `cli/core/process`;
no script or Makefile is forwarded to a host shell or Make executable.

This phase adds measured compatibility behavior, but it does not justify full
POSIX shell or GNU Make claims. Both language rows remain `partial`: parser and
evaluator size is an implementation backlog, not proof that pure MoonBit is
incapable of implementing the language.

## Delivered behavior

- `env` preserves the Native parent environment, supports clean environments,
  unset/assignment, bare `-`, NUL records, and `-C/--chdir`; command lookup and
  launch failures retain 126/127 mappings. Wasm retains its explicit policy
  environment.
- `xargs` supports whitespace/quote parsing, NUL input, bounded `-n` batches,
  `-I` logical-line replacement, no-input control, and GNU's 123/124/125/126/127
  child outcome classes for the measured paths.
- `sh` accepts `-c`, script files, implicit stdin, and explicit `-s` with
  positional parameters. Its MoonBit lexer/parser/executor continues to own
  quoting, expansion, conditionals, pipelines, redirections, and built-ins.
- `make` resolves `include`, `-include`, and `sinclude` relative to each source
  Makefile, limits include nesting, and gives command-line variables precedence
  over ordinary Makefile assignments. Recipes remain parsed by `cli/core/shell`.

## Remaining language surface

POSIX command substitution, here-documents, background execution, functions,
compound commands, traps, full parameter expansion, and several shell option
rules are not complete. GNU Make pattern/static rules, functions, conditionals,
generated includes/remake-and-restart, jobserver/parallel execution, built-in
rule databases, `define`/`eval`, export flavors, and complete diagnostics are
also not complete. `find -exec ... +` batching and action truth inside arbitrary
boolean expressions require a later findutils grammar increment.

These are not accepted permanent exceptions. Each must be implemented directly
in MoonBit and added to the pinned differential suite. Unsupported syntax fails
closed; it is never evaluated by `/bin/sh`, host `make`, or another wrapper.

`timeout` remains the one process capability exception. The public process API
can cancel a direct child but does not expose portable process-group or Windows
Job Object cancellation, so the module remains local-only and unpublished.
