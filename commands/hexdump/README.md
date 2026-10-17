# hexdump

Version **0.1.1** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Display binary data as numbers and readable characters:

```sh
moonx cli/hexdump -C data.bin
moonx cli/hexdump -s16 -n32 -v data.bin
printf 'abc' | moonx cli/hexdump -b
```

`-C` prints hexadecimal bytes and an ASCII column. `-b`, `-c`, and `-X`
select one-byte octal, escaped characters, and hexadecimal. `-d`, `-o`, and
`-x` print two-byte decimal, octal, and hexadecimal values. Without a format
option, two-byte hexadecimal values use the compact default layout. Repeated
format options produce one line per selected format, in option order.

Files are concatenated before formatting; no file, or `-`, reads stdin.
`-s` skips bytes in named files, `-n` limits displayed bytes, and `-v` prints repeated
blocks instead of `*`. Counts accept decimal, leading-zero octal, hexadecimal,
and common `K/M/G`, `KiB/MiB/GiB`, `KB/MB/GB`, or `b` suffixes. Final partial
words are zero-padded and absent fields retain their column spacing.

Two-byte values use the little-endian profile of the supported Native/Wasm
targets. Character output uses C-locale byte rules. Custom `-e`/`-f` format
strings and color directives are not implemented. `-h`/`--help` and
`-V`/`--version` are available. Errors return status 1.

Skipping bytes from stdin is rejected because its seekability cannot be
checked through the public input API. `-n0` completes without reading input.

## Standalone metadata

Standalone `--version` prints exactly `hexdump 0.1.1` followed by one
newline. Standalone `--help` starts with `Usage: hexdump`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
