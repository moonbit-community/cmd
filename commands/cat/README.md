# cat for moonx

Support note (2026-09-05): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it separates native compatibility evidence from Wasm policy and smoke evidence. Options mentioned here but not promoted in that record are not compatibility guarantees.

Concatenate files or stdin to stdout, byte-transparently:

```sh
moonx cli/cat a.txt b.txt
printf '\x00\xff' | moonx cli/cat | moonx cli/xxd -p   # 00ff
```

Bytes pass through unmodified when no formatting option is selected. `-n` and
`-b` number lines, `-s` squeezes repeated blank lines, and `-A`, `-e`, `-E`,
`-t`, `-T`, and `-v` expose the common GNU visible-byte forms. Formatting
state is continuous across file operands, including an unterminated line at a
file boundary. Use `-` (or no argument) to read stdin. `-u`/`--unbuffered` is
accepted as the GNU compatibility no-op; MoonBit writes through its byte stream
without an additional user-space buffer.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.
