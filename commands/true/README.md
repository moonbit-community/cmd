# true for moonx

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Do nothing, successfully:

```sh
moonx cli/true && echo it worked
```

Ignores all arguments, produces no output, and exits with status 0. `--help`
and `--version` print the corresponding metadata and still exit successfully.
The version token matches the package version in `moon.mod`.

## Standalone metadata

Standalone `--version` prints exactly `true 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: true`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
