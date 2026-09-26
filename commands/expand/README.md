# expand

Version **0.1.0** behavior is documented here. The
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
