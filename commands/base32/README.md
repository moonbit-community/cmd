# base32 for moonx

Version **0.1.0** behavior is documented here. The
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
