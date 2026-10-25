# od

Version **0.1.2** behavior is documented here. The
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

Floating formats use the frozen GNU Linux amd64 profile on all hosts and
backends: `f/f8/fD` is IEEE binary64, `f4/fF` is IEEE binary32, and `f16/fL`
is the x87 80-bit value stored in a 16-byte slot. `f2/fH` is IEEE binary16 and
`fB` is bfloat16; their decimal rendering follows promotion to binary32.
The frozen provider has no 10- or 12-byte floating type. `-f` selects `fF`; `-e/-F` selects
`fD`. Conversion preserves signed zero, infinities, NaNs, subnormals and GNU's
round-trip decimal precision search without narrowing wider values to Double.
Short elements receive physical trailing zero bytes before endian conversion.

`-A` selects decimal, octal, hexadecimal, or no addresses (`d/o/x/n`). `-j`
skips bytes and `-N` limits bytes across the concatenation of all file operands.
Counts accept decimal, leading-zero octal, hexadecimal, and `b/K/M/G` suffixes.
No file, or `-`, reads stdin. `-wN` controls line width; bare `-w` selects 32
bytes, and the default is 16. Zero selects that default. A width incompatible
with the selected type sizes warns and uses their common unit size, matching
the frozen provider. Widths are bounded at 1048576. `-v` disables duplicate-line folding.

The current profile uses little-endian integers by default on supported
Native/Wasm targets; `--endian=big` or `--endian=little` selects byte order
explicitly. Characters use C-locale byte rules.

`-S N` or `--strings[=N]` prints runs of at least N printable C bytes terminated by NUL
or the selected `-N` boundary; the default minimum is 3. A run cut off by EOF
is not printed. Candidates span input files and read chunks. String mode
cannot be combined with an explicit output type.

`--traditional` accepts one optional file followed by old offset and label
operands. These use octal by default, `0x` for hexadecimal, a trailing dot for
decimal, and optional `b` (512) or `B` (1024) block multipliers. Labels appear in parentheses.
With `-An`, the frozen provider displays the true offset in those parentheses.
Without modern options, the applicable POSIX `+OFFSET` form is also accepted;
modern options retain file operand interpretation unless `--traditional` is
explicit. `--help` and `--version` are available. Errors return 1.

## Standalone metadata

Standalone `--version` prints exactly `od 0.1.2` followed by one
newline. Standalone `--help` starts with `Usage: od`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
