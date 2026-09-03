# cat for moonx

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

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
