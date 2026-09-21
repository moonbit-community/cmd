# false for moonx

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Do nothing, unsuccessfully:

```sh
moonx cli/false || echo it failed
```

Ignores all arguments, produces no output, and exits with status 1. `--help`
and `--version` print the corresponding metadata and exit successfully. The
version token matches the package version in `moon.mod`.
