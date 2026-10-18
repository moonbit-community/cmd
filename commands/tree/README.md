# tree

Version **0.1.3** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Display a sorted recursive directory tree:

```sh
moonx cli/tree .
moonx cli/tree -L 2 --noreport project/
```

The verified profile supports `-a`/`--all`, `-d`/`--dirs-only`,
`-f`/`--full-path`, `-L`/`--level`, and `--noreport`, with one or more roots.
Symbolic-link entries are rejected explicitly because the released public
filesystem API does not expose link targets. Color, ownership, permissions,
device metadata and extended reports are outside this profile.
`--help` prints usage and `--version` prints the command and package version.

## Standalone metadata

Standalone `--version` prints exactly `tree 0.1.3` followed by one
newline. Standalone `--help` starts with `Usage: tree`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
