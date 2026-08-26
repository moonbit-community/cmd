# cat for moonx

Concatenate files or stdin to stdout, byte-transparently:

```sh
moonx mooxCLI/cmd/cat a.txt b.txt
printf '\x00\xff' | moonx mooxCLI/cmd/cat | moonx mooxCLI/cmd/xxd -p   # 00ff
```

Bytes pass through unmodified — no UTF-8 decoding and no newline
normalization, so binary data is safe. Use `-` (or no argument) to read
stdin. No formatting flags.
