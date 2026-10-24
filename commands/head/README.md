# head for moonx

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Record, byte and multi-file header output share a 64 KiB buffer. Input errors
flush already completed output; an output failure stops without replaying bytes.

Print the first lines or bytes of files or stdin:

```sh
printf '1\n2\n3\n' | moonx cli/head -n 2
moonx cli/head -c 16 data.bin
```

Options: `-n N` first N records (default 10), `-c N` first N bytes, and
`-q`/`-v` header control. `-z` makes line records NUL-terminated. Count values
accept attached, separate, and long-option forms, the legacy `-NUM` spelling,
negative counts to exclude the last NUM units, an explicit `+NUM`, and
documented decimal, short binary, and IEC (`KiB` through `QiB`) size suffixes.
The obsolete first-argument form supports its documented `b`/`k`/`m` units and
`c`/`l`/`q`/`v` modifiers. The last `-n`/`-c` and `-q`/`-v` occurrence controls
its mode.

Positive prefixes stop after the requested quota. Negative record counts keep
only the excluded suffix in memory; negative byte counts keep at most the
requested suffix plus one input chunk.

With no file operand, the command silently reads stdin until EOF or the quota
is satisfied; terminal, pipe, redirection, and explicit `-` paths are clean.

## Standalone metadata

Standalone `--version` prints exactly `head 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: head`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
