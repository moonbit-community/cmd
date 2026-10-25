# false for moonx

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Do nothing, unsuccessfully:

```sh
moonx cli/false || echo it failed
```

Ignores all arguments, produces no output, and exits with status 1. Standalone
`--help` and `--version` print the corresponding metadata and exit successfully. The
version token matches the package version in `moon.mod`.

## Standalone metadata

Standalone `--version` prints exactly `false 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: false`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
