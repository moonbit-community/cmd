# base32 for moonx

`base32` encodes or decodes a file or standard input using the RFC 4648
uppercase alphabet (`A-Z` and `2-7`). It is implemented in pure MoonBit and
has the same byte-oriented behavior on Native and Wasm.

```sh
printf 'foo' | moonx cli/base32
printf 'MZXW6===' | moonx cli/base32 -d
moonx cli/base32 -w0 input.bin
```

The supported options are `-d`/`--decode`, `-i`/`--ignore-garbage`, and
`-w COLS`/`--wrap=COLS`. Encoding wraps at 76 columns by default. `-w0`
disables wrapping and the final newline. Decoding accepts line feeds between
groups; the GNU alphabet is uppercase only, and with `-i`, other bytes outside
the alphabet are ignored. Exactly one file operand is accepted; `-` or no
operand reads standard input. Complete decoded groups are written immediately,
so a later malformed group can leave a valid prefix on stdout.

Invalid padding, incomplete groups, and invalid wrap sizes are errors and
return status 1 or 2 for argument errors. As in GNU coreutils, non-zero unused
tail bits are accepted during decoding.
