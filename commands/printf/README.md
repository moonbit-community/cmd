# printf for moonx

Support note (2026-09-05): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it separates native compatibility evidence from Wasm policy and smoke evidence. Options mentioned here but not promoted in that record are not compatibility guarantees.

Format and print data like printf(1):

```sh
moonx cli/printf '%s=%d\n' answer 42
moonx cli/printf '%5.2f|%-8x|%o\n' 3.14159 255 8
moonx cli/printf '%s\n' one two three   # format reused per argument
moonx cli/printf '\x41é\n'
```

Supported: the escapes `\a \b \e \f \n \r \t \v \\ \" \' \NNN \0NNN \xHH
\uHHHH \UHHHHHHHH \c` (stop output); the conversions `%s %c %b %d %i %u %o
%x %X %f %e %E %g %G %%` with flags `-+ 0#`, field width, and precision
(width and precision accept `*`). `%b` interprets escapes in its argument.
Numeric arguments accept decimal, `0x` hex, leading-`0` octal, and `'C` for
a character code. The format is reused until all arguments are consumed.

Float conversions use the exact decimal expansion of the double with
round-half-even, matching GNU printf digit for digit. Use `--` before a
FORMAT that starts with `-`. Invalid numeric prefixes produce the converted
prefix plus a diagnostic and status 1; the format is still repeated as needed.
