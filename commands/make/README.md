# make

`cli/make` is a MoonBit implementation of the core Make workflow for
native and Wasm targets. It parses Makefiles, expands variables, builds and
checks the dependency graph, compares modification times, and executes recipes
through `cli`'s MoonBit shell interpreter.

`include`, `-include`, and `sinclude` resolve relative to the Makefile that
contains them. Command-line variable assignments take precedence over ordinary
Makefile assignments. Include and variable expansion depth is bounded at 64.

Each external command in a recipe is launched through the policy-visible
MoonBit process API. Unsupported Make extensions fail explicitly; the complete
Makefile is never forwarded to a host `make` executable. The remaining
language surface is listed in the
[Phase 5 process/language spike](../../docs/spikes/2026-09-03-process-language-phase5.md).

Native recipes inherit the complete parent environment plus Make variables.
Wasm recipes start from the explicit restricted environment and remain subject
to the host process policy.
