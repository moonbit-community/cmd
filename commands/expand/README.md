# expand

Version **0.1.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Convert tab bytes to spaces while preserving the remaining input bytes:

```sh
printf 'a\tb\n' | moonx cli/expand
moonx cli/expand -t 4,8 input.txt
```

`-i`/`--initial` limits conversion to the leading blank area, and
`-t`/`--tabs` selects positive ascending tab stops; the default stop is 8.
With no file operand, or with `-`, input is read from standard input. Multiple
files are processed in order and a read error does not discard earlier output.
Locale-dependent display widths are outside this byte-oriented profile.

## Standalone metadata

Standalone `--version` prints exactly `expand 0.1.2` followed by one
newline. Standalone `--help` starts with `Usage: expand`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
