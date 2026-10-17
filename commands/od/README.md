# od

Version **0.1.1** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Display bytes as octal, hexadecimal, decimal, or characters:

```sh
moonx cli/od -Ax -tx1 data.bin
moonx cli/od -An -tu1 -N16 data.bin
moonx cli/od -j4 -N8 --endian=big -tx2 data.bin
```

With no format option, `od` prints two-byte octal values and octal addresses.
`-t`/`--format` accepts named characters (`a`), escaped characters (`c`), and
signed decimal (`d`), unsigned decimal (`u`), octal (`o`), or hexadecimal (`x`)
integers of 1, 2, 4, or 8 bytes. Integer sizes default to 4; `C/S/I/L` select
1/2/4/8 bytes. Append `z` for a printable ASCII trailer. Formats can be combined
or repeated. `-a/-b/-c/-d/-i/-l/-o/-s/-x` select the traditional formats.

`-A` selects decimal, octal, hexadecimal, or no addresses (`d/o/x/n`). `-j`
skips bytes and `-N` limits bytes across the concatenation of all file operands.
Counts accept decimal, leading-zero octal, hexadecimal, and `b/K/M/G` suffixes.
No file, or `-`, reads stdin. `-wN` controls line width; bare `-w` selects 32
bytes, and the default is 16. Widths must be multiples of every selected type
size and at most 1048576. `-v` disables duplicate-line folding.

The current profile uses little-endian integers by default on supported
Native/Wasm targets; `--endian=big` or `--endian=little` selects byte order
explicitly. Characters use C-locale byte rules. Floating-point formats,
string extraction, and traditional offset operands are not implemented;
use `-j` for offsets. `--help` and `--version` are available. Errors return 1.

## Standalone metadata

Standalone `--version` prints exactly `od 0.1.1` followed by one
newline. Standalone `--help` starts with `Usage: od`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
