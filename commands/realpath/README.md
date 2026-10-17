# realpath

Version **0.1.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Print canonical paths for one or more operands:

```sh
moonx cli/realpath -e input.txt
moonx cli/realpath -z input.txt other.txt
```

`-e`/`--canonicalize-existing` requires every component to exist, and
`-z`/`--zero` terminates records with NUL bytes. Operands are handled
independently; a failed operand does not erase earlier output. Missing-path `-m`
semantics and other metadata-dependent modes are not included.
`--help` prints usage and `--version` prints the command and package version.

## Standalone metadata

Standalone `--version` prints exactly `realpath 0.1.2` followed by one
newline. Standalone `--help` starts with `Usage: realpath`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
