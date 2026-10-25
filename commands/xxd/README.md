# xxd for moonx

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Make a hex dump, or reverse one back into bytes:

```sh
printf 'hello' | moonx cli/xxd
moonx cli/xxd -p data.bin            # plain continuous hex
moonx cli/xxd -r dump.txt > out.bin  # reverse a dump
printf '68690a' | moonx cli/xxd -r -p
```

`-p`/`-ps` prints plain hex, `-b` prints bits, `-e` reverses bytes within
little-endian groups, and `-i` prints C include text. The last style option
wins. `-E` changes only the character display to the fixed provider's EBCDIC
mapping; bytes and numeric fields remain unchanged. `-u` selects uppercase
hex digits. `-g N` selects group size, including zero for an ungrouped line;
little-endian explicit groups must satisfy the provider's power-of-two rule.
`-c N` sets columns (defaults: 16 hex, 6 bits, 30 plain, 12 include). Zero
restores the style default, except plain zero disables wrapping. Numeric
options retain the fixed provider's base-zero prefix parsing. `-a` toggles
zero-line suppression on every occurrence and keeps the required final line.

`-l N` limits input bytes, `-o N` adds to displayed addresses, and `-s N`
chooses the input position. Display addresses use the frozen 64-bit unsigned
profile; other logical offsets use checked 64-bit arithmetic. A positive
stdin skip reads and discards bytes. Named regular files support absolute,
relative `+N`, end-relative `-N`, and relative-backward `+-N` positions through
public size/read-at operations. Backward positions before the start fail.
Negative or backward stdin seeks are rejected: the public stdin interface has
no seek/borrowed-File operation, including when stdin is a redirected file.
Include text accepts `-n NAME` and streams with the selected columns and limit.

`-r`/`--reverse` (also `--revert`) reverses addressed hex, plain hex, or binary
dumps; little-endian and include reverse modes return the provider's
unsupported-mode diagnostic.
Reverse `-s N` adds to addresses instead of skipping input. Loose garbage,
incomplete digits, and columns follow the Vim provider. Stdout accepts forward
holes as NUL bytes and rejects backward writes while retaining the emitted
prefix. A newly created output file supports sparse holes and backward patching
with public write-at operations. The former 16 MiB allocation ceiling is
removed; reverse decoding no longer retains the complete output in memory.

A second operand selects the output file; `-` selects stdout. New files use
exclusive creation. Existing outputs, including same-path and hard-link alias
possibilities, are rejected before mutation. Released public APIs do not expose
file identity for checking the input/output relation. This boundary can be
lifted when that API is available or an explicit safe spool/overwrite policy is
adopted. No realpath or byte-content comparison substitutes for inode identity.

Input and reverse output use fixed 64 KiB batches; display rows, autoskip state,
and formatting batches remain bounded independently of total input size.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.

## Standalone metadata

Standalone `--version` prints exactly `xxd 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: xxd`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
