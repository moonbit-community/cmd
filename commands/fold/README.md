# fold

Version **0.1.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Wrap input lines to a chosen width:

```sh
moonx cli/fold -w 72 notes.txt
moonx cli/fold -s -w 40 notes.txt
printf 'abcdef\n' | moonx cli/fold -b -w 3
```

The default width is 80 columns. `-w`/`--width` selects a positive width;
the traditional `-WIDTH` spelling is also accepted. `-b`/`--bytes` counts
bytes, `-c`/`--characters` selects C-locale characters, and `-s`/`--spaces`
breaks after the last available space or tab without dropping it. Long words
are split when necessary. In column mode, tabs advance to the next eight-column
stop, backspace moves back, and carriage return resets the column.

Files are processed in operand order. No file, or `-`, reads stdin. An
unterminated final line stays unterminated. Input bytes, including NUL and
invalid UTF-8, are preserved. Locale-dependent Unicode display widths and
multibyte character counting are outside the current C-locale profile.
`--help` and `--version` are available. Errors return status 1.
