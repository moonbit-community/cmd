# sleep for moonx

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Pause for a number of seconds:

```sh
moonx cli/sleep 2
moonx cli/sleep 0.5
moonx cli/sleep 1m 30s   # arguments are summed
```

NUMBER may be fractional; suffixes `s`, `m`, `h`, `d` scale it. With
multiple arguments, sleeps for their sum.

`--help` and `--version` are handled without sleeping. The version token matches
the package version in `moon.mod`.
`--` explicitly ends option parsing before a duration operand.

## Standalone metadata

Standalone `--version` prints exactly `sleep 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: sleep`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
