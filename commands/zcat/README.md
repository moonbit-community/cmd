# zcat

Version **0.1.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Write the decoded contents of gzip files to stdout, keeping the input files:

```sh
moonx cli/zcat first.gz second.gz
cat first.gz | moonx cli/zcat
```

With no file or with `-`, read stdin. Operands are processed in order. `-c` and
`-d` explicitly select the default stdout/decompression behavior; `-t` validates
without output. `-n` is accepted because stdout output never restores metadata.

Concatenated members, optional header fields and CRC/size checks follow the
same gzip behavior as `gunzip`. Compressed input is buffered and decoded bytes
are written in chunks. Invalid or truncated data returns 1, preserving any
decoded prefix; trailing garbage returns 2. `-q` suppresses trailing-garbage
warnings, and `--help`/`--version` provide command information.

Only gzip input is accepted. Other compression formats, filename suffix
searching, force/pass-through behavior and metadata restoration are not supported.

## Standalone metadata

Standalone `--version` prints exactly `zcat 0.1.2` followed by one
newline. Standalone `--help` starts with `Usage: zcat`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
