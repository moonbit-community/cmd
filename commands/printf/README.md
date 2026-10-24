# printf for moonx

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Format and print data like printf(1):

```sh
moonx cli/printf '%s=%d\n' answer 42
moonx cli/printf '%5.2f|%-8x|%o\n' 3.14159 255 8
moonx cli/printf '%s\n' one two three   # format reused per argument
moonx cli/printf '\x41é\n'
```

Supported: the escapes `\a \b \e \f \n \r \t \v \\ \" \' \NNN \0NNN \xHH
\uHHHH \UHHHHHHHH \c` (stop output); the conversions `%s %c %b %d %i %u %o
%x %X %f %F %e %E %g %G %a %A %%` with flags `-+ 0#`, field width, and precision
(width and precision accept `*`). `%b` interprets escapes in its argument.
Numeric arguments accept decimal, `0x` hex, leading-`0` octal, and `'C` for
a character code. The format is reused until all arguments are consumed.

Float conversions use the frozen GNU Linux amd64 extended-precision profile
(64 significand bits and the x87 exponent range), with exact conversion and
round-half-even on every supported host and backend. Hexadecimal `%a/%A` preserves negative zero, subnormals,
special values and requested precision, with Linux GNU forms such as
`0xcp-3` for 1.5. NaN retains its sign and requested plus/space flags. Zero padding follows the sign and
`0x` prefix. The running host's long-double ABI is not selected, and non-C
locale behavior is not claimed. Use `--` before a
FORMAT that starts with `-`. Invalid numeric prefixes produce the converted
prefix plus a diagnostic and status 1; the format is still repeated as needed.

Bare `%q` emits GNU C-byte shell quoting, including ANSI-C escapes for controls
and non-ASCII bytes. A real empty argument prints `''`; a missing argument
prints nothing. Flags, width and precision on `%q` reject the conversion while
retaining output already produced before it.

## Standalone metadata

Standalone `--version` prints exactly `printf 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: printf`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
