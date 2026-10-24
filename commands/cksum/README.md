# cksum for moonx

Version **0.1.3** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Compute the POSIX CRC-32 checksum and byte count:

```sh
printf 'hello' | moonx cli/cksum
moonx cli/cksum input.bin
```

With no operand, or with `-`, standard input is read. Multiple operands are
processed in order; later file failures do not hide earlier results and produce
an eventual nonzero status. `--help` and `--version` are available.

The unpublished workspace candidate adds `-a/--algorithm`: `bsd`, `sysv`,
`crc`, `crc32b`, `md5`, `sha1`, `sha224`, `sha256`, `sha384`,
`sha512`, `sha2`, `sha3`, `blake2b`, and `sm3`. SHA2 and SHA3 require
`-l/--length` 224, 256, 384 or 512 when hashing. BLAKE2b supports every
multiple of eight from 8 through 512; zero selects its 512-bit default.
Legacy algorithms print their decimal checksum and byte/block count. Modern
algorithms print BSD tagged records by default; `--untagged` selects GNU
checksum records. `--base64` changes the modern digest encoding, and `--raw`
writes only digest bytes for one input. Legacy raw digests use big-endian order.
`-z/--zero` ends records with NUL and disables filename escaping.

`-c/--check` verifies modern tagged records, automatically selecting their
algorithm unless `-a` is specified. With an explicit modern algorithm it also
accepts untagged records; SHA2, SHA3 and BLAKE2b lengths are inferred from each
record. Like GNU, explicit SHA2 checking locks to the first fixed SHA tag in a
manifest; omit `-a` to check a mixture of fixed SHA tags. Hexadecimal and Base64
digests are accepted. Legacy checksum formats
cannot be verified. `--quiet`, `--status`, `-w/--warn`, `--strict` and
`--ignore-missing` follow the sum commands. At least one digest must match,
including when missing files are ignored. Status mode still reports read errors.
Explicit `--tag`, `-b/-t` and `-z` are invalid while checking.

Hash input uses bounded buffers, including SHA3 and BLAKE2b; manifests are read
one line at a time. Backslash, LF and CR in modern record filenames are escaped.
Binary and text flags select record markers; neither translates input bytes on
Windows. `--base64` and `--raw` conflict, and text output requires
`--untagged`. This candidate does not change the frozen published coordinates.

## Standalone metadata

Standalone `--version` prints exactly `cksum 0.1.3` followed by one
newline. Standalone `--help` starts with `Usage: cksum`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
