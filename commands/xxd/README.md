# xxd for moonx

Make a hex dump, or reverse one back into bytes:

```sh
printf 'hello' | moonx cli/xxd
moonx cli/xxd -p data.bin            # plain continuous hex
moonx cli/xxd -r dump.txt > out.bin  # reverse a dump
printf '68690a' | moonx cli/xxd -r -p
```

Options: `-p` plain hex, `-r` reverse (with or without `-p`), `-c N` bytes
per line (default 16, or 30 with `-p`), `-l N` stop after N bytes, and `-s N`
seek before a forward dump. In reverse mode a positive `-s N` shifts output
by N bytes. Negative/end-relative seeks and full addressed reverse-patching
semantics remain outside the measured slice.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.
