# od

Version **0.1.0** is a local candidate. See the
[support record](../../docs/compatibility.md) for verification and release status.

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
