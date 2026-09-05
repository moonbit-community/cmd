# false for moonx

Support note (2026-09-05): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it separates native compatibility evidence from Wasm policy and smoke evidence. Options mentioned here but not promoted in that record are not compatibility guarantees.

Do nothing, unsuccessfully:

```sh
moonx cli/false || echo it failed
```

Ignores all arguments, produces no output, and exits with status 1. `--help`
and `--version` print the corresponding metadata and exit successfully.
