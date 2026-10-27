# cksum

Compute and verify checksums for MoonX.

```sh
moonx cli/cksum@0.1.4 [OPTION]... [FILE]...
```

## Supported scope

Process files or stdin. Default is POSIX CRC-32 plus byte count. Algorithms: bsd, sysv, crc, crc32b, md5, sha1, sha224, sha256, sha384, sha512, sha2, sha3, blake2b and sm3. Modern digests support tagged/untagged records and verification.

## Options

| Option | Description |
| --- | --- |
| `-a, --algorithm=TYPE` | Select the checksum algorithm listed above. |
| `-l, --length=BITS` | SHA2/SHA3: 224, 256, 384, 512; BLAKE2b: 8..512 by 8 |
| `--untagged` | omit algorithm tags (modern digests default to tags) |
| `--base64` | encode modern digests in Base64 |
| `--raw` | write digest bytes without names or separators |
| `-b, --binary` | mark untagged output as binary |
| `-t, --text` | mark untagged output as text (default) |
| `--tag` | print BSD tagged records |
| `-c, --check` | read checksum records and verify files |
| `-z, --zero` | end output records with NUL; disable escaping |
| `--ignore-missing` | skip missing files when checking |
| `--quiet` | suppress successful verification output |
| `--status` | suppress verification results and summaries |
| `--strict` | fail if a checksum line is malformed |
| `-w, --warn` | warn for each malformed checksum line |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Legacy checksum formats cannot be verified with --check.
- Binary/text flags change record markers, not input bytes. --raw accepts one input and conflicts with --base64.
- Check mode rejects explicit --tag, -b/-t and -z; at least one digest must match even with --ignore-missing.

## Examples

```sh
moonx cli/cksum@0.1.4 input.bin
moonx cli/cksum@0.1.4 -a sha256 input.bin
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0008-data.md)
