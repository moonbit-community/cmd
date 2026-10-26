# cut for moonx

Unpublished candidate **0.2.3** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

The candidate batches immutable input views and output bytes through core 0.8.2.
It selects a synchronous byte/field visitor once per input and stops field
selection after the last requested field, with separate compatibility paths
for equal delimiters and empty selections.
Options, record endings and special field-delimiter cases retain their contracts.

Select fields or character positions from each line:

```sh
printf 'x,y,z\n' | moonx cli/cut -d, -f1,3
moonx cli/cut -c 1-4 fixed.txt
```

Options: `-f LIST` field list, `-b LIST` byte list, `-c LIST` character list
(the latter two are identical under the fixed C-locale byte profile), `-d CHAR` field
delimiter (default TAB), `-s` skip lines without the delimiter, and `-z`
for NUL-delimited records. `--complement` selects positions outside the list;
`--output-delimiter=STRING` joins selected fields or byte/character ranges.
An empty output delimiter emits one NUL. Lists
accept `N`, `N-M`, `N-`, and `-M`, separated by commas; output preserves
input order. Overlapping ranges merge; adjacent explicitly listed ranges retain
their output separator, so `-b1-2,3-4 --output-delimiter='|'` prints `ab|cd`.

An empty `-d` value selects NUL as the field delimiter. Non-delimited records
pass through unchanged unless `-s` is present when the selection contains fields.
If complement removes every field, GNU 9.11 handles undelimited input by blocks:
a block containing field separators emits only record terminators, and an
unterminated tail can be omitted. This behavior is retained for compatibility.
When field and record delimiters are identical, field positions span the input
file rather than resetting at every delimiter; a final delimiter terminates
the last field without creating an extra empty field.
Delimiter and `-s` options are rejected outside field mode.

## Standalone metadata

Standalone `--version` prints exactly `cut 0.2.3` followed by one
newline. Standalone `--help` starts with `Usage: cut`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
