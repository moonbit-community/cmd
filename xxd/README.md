# xxd for moonx

Make a hex dump, or reverse one back into bytes:

```sh
printf 'hello' | moonx mooxCLI/cmd/xxd
moonx mooxCLI/cmd/xxd -p data.bin            # plain continuous hex
moonx mooxCLI/cmd/xxd -r dump.txt > out.bin  # reverse a dump
printf '68690a' | moonx mooxCLI/cmd/xxd -r -p
```

Options: `-p` plain hex, `-r` reverse (with or without `-p`), `-c N` bytes
per line (default 16, or 30 with `-p`), `-l N` stop after N bytes.
Reverse mode ignores offsets and concatenates the hex columns in order.
