# xxd for moonx

Make a hex dump, or reverse one back into bytes:

```sh
printf 'hello' | moonx cli/xxd
moonx cli/xxd -p data.bin            # plain continuous hex
moonx cli/xxd -r dump.txt > out.bin  # reverse a dump
printf '68690a' | moonx cli/xxd -r -p
```

Options: `-p` plain hex, `-r` reverse (with or without `-p`), `-c N` bytes
per line (default 16, or 30 with `-p`), `-l N` stop after N bytes.
Reverse mode ignores offsets and concatenates the hex columns in order.
