# fmt

Version **0.1.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Reformat paragraphs from files or stdin while preserving indentation and
sentence spacing. Blank lines separate paragraphs. Ordinary paragraphs keep
one indent; crown and tagged modes distinguish the first and continuation
indents. Reformatted paragraphs end with a newline.

```sh
moonx cli/fmt -w 60 notes.txt
moonx cli/fmt -s -w 40 notes.txt
```

`-w/--width` sets the maximum width, with a default of 75. The GNU `-WIDTH`
shorthand is also supported. `-g/--goal` sets the preferred width and must not
exceed the selected width. With no explicit width, goals from 0 through 75 are
accepted and the maximum becomes goal plus 10. `-s/--split-only` keeps input lines
separate, and `-u/--uniform-spacing` uses one space between words and two
after sentence endings. Widths range from 0 through 2500; a long word is
emitted intact even when it exceeds the width. Columns use a C-locale byte
profile, and tabs advance to multiples of eight.

`-c/--crown-margin` allows the first indent to differ from the remaining
lines. `-t/--tagged-paragraph` joins a second line only when its indent differs
from the first, and retains the continuation indent for later paragraphs.
Split mode takes precedence over crown mode, then tagged mode, independent
of their argument order.

`-p/--prefix=PREFIX` reformats matching prefixed lines and repeats the prefix
on output. Leading and trailing spaces in the requested prefix affect
eligibility; unmatched lines retain their contents, including a missing final
newline. An empty prefix selects ordinary lines. Repeated prefixes use the last.

No file is rewritten. Multiple operands are processed in order and an
unreadable file does not stop later operands. Locale-aware character widths
are outside the selected C-byte profile.
`--help` and `--version` are available. Exit status is 0 on success and 1
for an option or input error.

## Standalone metadata

Standalone `--version` prints exactly `fmt 0.1.2` followed by one
newline. Standalone `--help` starts with `Usage: fmt`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
