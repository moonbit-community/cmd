# comm for moonx

Version **0.2.1** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Compare two sorted files line by line, producing three columns: lines only
in FILE1, lines only in FILE2 (one leading TAB), and common lines (two
leading TABs):

```sh
moonx cli/comm left.txt right.txt
moonx cli/comm -12 left.txt right.txt   # only common lines
```

Options: `-1`, `-2`, `-3` suppress the corresponding column (combinable as
`-12`, `-23`, ...). Use `-` to read stdin. Records are compared as raw bytes,
matching `LC_ALL=C` order. `--check-order` reports
an unsorted input and exits nonzero. By default, disorder is diagnosed once
unpairable input is observed, matching GNU's conditional check.
`-z` reads and writes NUL-delimited records; `--nocheck-order` explicitly
selects permissive order handling whenever both order flags are present.

## Standalone metadata

Standalone `--version` prints exactly `comm 0.2.1` followed by one
newline. Standalone `--help` starts with `Usage: comm`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
