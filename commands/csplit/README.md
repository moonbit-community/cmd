# csplit

Version **0.1.1** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Split a file into sections at line numbers or basic regular expressions:

```sh
moonx cli/csplit input.txt 10 20
moonx cli/csplit -s -f section- input.txt '/^Chapter/' '{*}'
```

`NUMBER` splits before that absolute line; `/REGEXP/` splits before a matching
line and `%REGEXP%` discards the preceding section. Regex delimiters may be
followed by a positive or negative line offset. `{N}` repeats the preceding
pattern N additional times. Regex `{*}` repeats through the remaining input;
numeric repetitions that reach beyond the last line report an error.
The first operand `-` reads stdin. All input bytes, including NUL and an
unterminated final line, are preserved in selected fragments.

Files are named `xx00`, `xx01`, … . `-f`/`--prefix` changes the prefix and
`-n`/`--digits` sets the minimum number of suffix digits. Byte counts are printed
for created files unless `-s`/`--silent` or `-q`/`--quiet` is selected.
`-z`/`--elide-empty-files` omits empty fragments. Split failures remove the files
created by that invocation unless `-k`/`--keep-files` is used.

Input is buffered and matching uses ASCII patterns over byte-valued lines.
Existing output paths are refused. Backreferences, word extensions, non-ASCII
patterns, locale-sensitive matching, custom suffix formats and
`--suppress-matched` are rejected. `--help` and `--version` provide command
information.

## Standalone metadata

Standalone `--version` prints exactly `csplit 0.1.1` followed by one
newline. Standalone `--help` starts with `Usage: csplit`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
