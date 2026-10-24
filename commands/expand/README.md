# expand

Version **0.1.3** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Convert tab bytes to spaces while preserving the remaining input bytes:

```sh
printf 'a\tb\n' | moonx cli/expand
moonx cli/expand -t 4,8 input.txt
```

`-i`/`--initial` limits conversion to the leading blank area, and
`-t`/`--tabs` selects positive ascending tab stops; the default width is 8.
A single stop repeats at that width. With several fixed stops, later tabs
become one space. A final `/N` continues at absolute multiples of N; a final
`+N` continues relative to the last fixed stop. For example, after `4,6`,
`/8` places the next stop at 8, while `+8` places it at 14. A standalone
`/8` or `+8` is the ordinary repeating width 8.

Lists accept comma, space or tab separators, and repeated `-t` values
accumulate before validation. Stops use the GNU signed 64-bit range, rather
than an Int32 limit. Nonzero `/N` and `+N` suffixes are exclusive and may
not be repeated. GNU 9.11 accepts trailing `/0` or `+0` as no extension;
`4,/0` and `4,+0` therefore repeat width 4. Invalid tab lists fail before
input is read. Backspace moves back one positive column; carriage return is
an ordinary byte and does not reset the column.

With no file operand, or with `-`, input is read from standard input. Multiple
files are processed in order and a read error does not discard earlier output.
Locale-dependent display widths are outside this byte-oriented profile.

## Standalone metadata

Standalone `--version` prints exactly `expand 0.1.3` followed by one
newline. Standalone `--help` starts with `Usage: expand`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
