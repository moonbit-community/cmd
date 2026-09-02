# cat for moonx

Concatenate files or stdin to stdout, byte-transparently:

```sh
moonx cli/cat a.txt b.txt
printf '\x00\xff' | moonx cli/cat | moonx cli/xxd -p   # 00ff
```

Bytes pass through unmodified when no formatting option is selected. `-n` and
`-b` number lines, `-s` squeezes repeated blank lines, and `-A`, `-e`, `-E`,
`-t`, `-T`, and `-v` expose the common GNU visible-byte forms. Formatting
state is continuous across file operands, including an unterminated line at a
file boundary. Use `-` (or no argument) to read stdin.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.
