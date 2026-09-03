# base64 for moonx

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Base64 encode or decode a file or stdin:

```sh
printf 'hello' | moonx cli/base64
moonx cli/base64 -d encoded.txt
moonx cli/base64 -w 0 big.bin   # no line wrapping
```

Options: `-d` decode (whitespace in the input is ignored), `-w N` wrap
encoded output after N characters (default 76, `0` disables). Standard
alphabet with `=` padding.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.
