# xxd for moonx

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

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
