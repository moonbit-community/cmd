# unexpand

Version **0.1.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Convert eligible spaces to tabs while preserving input bytes and line
boundaries:

```sh
printf '    text\n' | moonx cli/unexpand
printf 'a    b\n' | moonx cli/unexpand -a
```

`-a`/`--all`, `--first-only`, and `-t`/`--tabs` select the conversion scope
and positive ascending tab stops; the default stop is 8. With no file operand,
or with `-`, input is read from standard input. Multiple files are processed in
order. Locale-dependent display widths are outside this byte-oriented profile.
