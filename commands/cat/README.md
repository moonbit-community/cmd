# cat for moonx

Version **0.2.1** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

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

## Standalone metadata

Standalone `--version` prints exactly `cat 0.2.1` followed by one
newline. Standalone `--help` starts with `Usage: cat`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
