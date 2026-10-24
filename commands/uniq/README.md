# uniq for moonx

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Filter adjacent repeated lines (pipe through sort first for global dedup):

```sh
sort words.txt | moonx cli/uniq
printf 'a\na\nb\n' | moonx cli/uniq -c
```

Options: `-c` prefixes occurrence counts in the GNU seven-column form, `-d`
selects repeated records, `-u` selects unrepeated records, and `-i` folds ASCII
case. `-f/--skip-fields` skips blank-delimited fields before
`-s/--skip-chars`; `-w/--check-chars` limits the compared suffix. `-z` or
`--zero-terminated` switches record input and output to NUL. Selection uses
the fixed `LC_ALL=C` byte profile, including malformed byte input.

`-D` or `--all-repeated[=METHOD]` prints every member of repeated groups,
omitting singleton groups. The default method `none` adds no separator;
`prepend` inserts a record separator before each output group and `separate`
inserts one only between output groups. A later bare `-D` resets the method to
`none`. With `-u -D`, every member except the last in each repeated group is
printed; `-d -u` without `-D` prints nothing.

`--group[=METHOD]` prints every input record and separates adjacent groups.
The default `separate` inserts separators only between groups. `prepend`,
`append`, and `both` also select separators at the beginning, end, or both.
Empty input prints no separators. Methods accept unambiguous abbreviations;
the last specified method is used. `--group` conflicts with `-c`, `-d`, `-D`,
and `-u`; `-c` also conflicts with `-D`. These conflicts are rejected before
input or output. Group output retains each original record and streams with
only one pending record and comparison key retained.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.

## Standalone metadata

Standalone `--version` prints exactly `uniq 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: uniq`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
