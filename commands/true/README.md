# true for moonx

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Do nothing, successfully:

```sh
moonx cli/true && echo it worked
```

Ignores all arguments, produces no output, and exits with status 0. `--help`
and `--version` print the corresponding metadata and still exit successfully.
The version token matches the package version in `moon.mod`.
