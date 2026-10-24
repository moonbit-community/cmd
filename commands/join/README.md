# join for moonx

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Join lines of two files sorted on their join fields:

```sh
moonx cli/join people.txt colors.txt
moonx cli/join -t, -1 2 -2 1 a.csv b.csv
```

Options: `-1 N` / `-2 N` choose the join field in each file (default 1), `-z`
uses NUL-delimited records,
`-t CHAR` field separator (default: runs of blanks, output separated by a
single space). `-a 1|2` includes unpairable rows, `-v 1|2` selects only
unpairable rows, and `-e STRING` supplies missing or empty fields. `-i` /
`--ignore-case` ignores ASCII case while comparing keys, preserving original
bytes in output. `--header` emits the first records together without comparing
their keys or checking header order, including with `-v`.

`-o LIST` selects join/output fields. `-o auto` freezes the number of fields
from each first record (the header with `--header`), omits later extra fields,
and pads missing fields with the `-e` replacement or empty fields. Repeated
explicit output lists accumulate and take precedence over `auto` in either
argument order.

`--check-order` rejects an out-of-order input key immediately;
`--nocheck-order` disables order checks. The last order flag takes effect.
The default reports disorder after an unpairable row makes it observable,
continues output, and exits nonzero at the end. Diagnostics identify the input
file, record number and offending record.
The merge streams both inputs and retains only the current equal-key runs.

## Standalone metadata

Standalone `--version` prints exactly `join 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: join`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
