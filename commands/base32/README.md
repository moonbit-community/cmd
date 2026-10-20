# base32 for moonx

Version **0.1.3** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Encode or decode byte input using the RFC 4648 Base32 alphabet:

```sh
printf 'hello' | moonx cli/base32
printf 'NBSWY3DP' | moonx cli/base32 -d
```

The profile supports `-d`/`--decode`, `-i`/`--ignore-garbage`, and
`-w`/`--wrap`; with no operand, input is read from standard input. Encoding
uses uppercase symbols and wraps at 76 columns by default. Lowercase input is
rejected, and a valid decoded prefix is written before a later malformed group
is reported. Nonstandard alphabets and locale-specific diagnostics are not
claimed.

## Standalone metadata

Standalone `--version` prints exactly `base32 0.1.3` followed by one
newline. Standalone `--help` starts with `Usage: base32`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
