# xxd for moonx

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Make a hex dump, or reverse one back into bytes:

```sh
printf 'hello' | moonx cli/xxd
moonx cli/xxd -p data.bin            # plain continuous hex
moonx cli/xxd -r dump.txt > out.bin  # reverse a dump
printf '68690a' | moonx cli/xxd -r -p
```

Options: `-p` plain hex, `-r`/`--revert` reverse (with or without `-p`), `-i`
include-style C output, `-c N` bytes
per line (default 16, or 30 with `-p`), `-l N` stop after N bytes, and `-s N`
seek before a forward dump. Include output accepts `-n NAME` for the C symbol;
addressed reverse dumps validate offsets and preserve sparse holes up to a
bounded output size. Non-dump text follows Vim xxd's loose offset scan and is
otherwise ignored; the same allocation bound applies. Negative/end-relative
seeks remain explicitly rejected.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.
