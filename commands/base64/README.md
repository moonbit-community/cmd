# base64 for moonx

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Base64 encode or decode a file or stdin:

```sh
printf 'hello' | moonx cli/base64
moonx cli/base64 -d encoded.txt
moonx cli/base64@0.2.0 -w0 big.bin # no wrapping or final newline
```

Options: `-d`/`-D` decode (embedded newlines are always accepted), `-i`/
`--ignore-garbage` discard non-alphabet bytes while decoding, and `-w N` wrap
encoded output after N characters (default 76, `0` disables wrapping and the
terminal newline); attached `-w0` is accepted. The alphabet is standard Base64
with `=` padding. Garbage mode ignores non-alphabet bytes; malformed Base64
can still fail.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.

## Standalone metadata

Standalone `--version` prints exactly `base64 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: base64`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
