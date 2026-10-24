# unexpand

Version **0.1.3** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Convert eligible spaces to tabs while preserving input bytes and line
boundaries:

```sh
printf '    text\n' | moonx cli/unexpand
printf 'a    b\n' | moonx cli/unexpand -a
```

`-a`/`--all` converts blanks throughout each line; the default converts only
the initial blank sequence. `-t`/`--tabs` implies `--all`. `--first-only`
overrides both explicit `-a` and the implication from `-t`, regardless of
option order. Existing tabs and isolated spaces retain their column meaning.

Tab lists use positive ascending stops separated by commas, spaces or tabs;
repeated `-t` values accumulate. The default width is 8, and a single stop
repeats at its width. Several fixed stops end conversion after their last
stop. A final `/N` extends at absolute multiples of N, while `+N` extends
relative to the last fixed stop: `4,6,/8` continues at 8,16,... and
`4,6,+8` at 14,22,... . A standalone `/8` or `+8` repeats width 8.

Stops use the GNU signed 64-bit range. Nonzero `/N` and `+N` suffixes are
exclusive and may not be repeated. GNU 9.11 accepts trailing `/0` or `+0`
as no extension, so `4,/0` and `4,+0` repeat width 4. Invalid lists fail
before input is read. Backspace decrements a positive column; carriage return
is an ordinary byte and does not reset it.

With no file operand, or with `-`, input is read from standard input. Multiple files are processed in
order. Locale-dependent display widths are outside this byte-oriented profile.

## Standalone metadata

Standalone `--version` prints exactly `unexpand 0.1.3` followed by one
newline. Standalone `--help` starts with `Usage: unexpand`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
