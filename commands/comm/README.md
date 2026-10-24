# comm for moonx

Version **0.2.2** behavior is documented here. The
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
matching `LC_ALL=C` order. `--output-delimiter=STR` replaces the column TABs;
an empty value selects one NUL byte. Repeated identical delimiters are accepted,
while differing values fail before output. `--total` appends the counts of
FILE1-only, FILE2-only and common records, followed by `total`, using the selected
column delimiter. Counts include suppressed columns.

`--check-order` reports an unsorted input and stops immediately. By default,
GNU's conditional order check diagnoses disorder after unpairable input is
observed; it finishes output and the requested total before exiting nonzero.
`--nocheck-order` disables checks. The last order flag takes effect.
`-z` reads and writes NUL-delimited records, including the total record.

## Standalone metadata

Standalone `--version` prints exactly `comm 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: comm`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
