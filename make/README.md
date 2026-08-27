# make

`mooxCLI/cmd/make` is a MoonBit implementation of the core Make workflow for
native and Wasm targets. It parses Makefiles, expands variables, builds and
checks the dependency graph, compares modification times, and executes recipes
through `mooxCLI/cmd`'s MoonBit shell interpreter.

Each external command in a recipe is launched through the policy-visible
MoonBit process API. Unsupported Make extensions fail explicitly; the complete
Makefile is never forwarded to a host `make` executable.
