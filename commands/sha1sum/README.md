# sha1sum

Compute and verify SHA-1 checksums for MoonX.

```sh
moonx cli/sha1sum@0.1.3 [OPTION]... [FILE]...
```

## Supported scope

Hash files or stdin and verify checksum manifests.

## Options

| Option | Description |
| --- | --- |
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

- Binary/text markers do not translate input bytes. Check mode requires at least one matching digest even with --ignore-missing.

## Examples

```sh
moonx cli/sha1sum@0.1.3 input.bin
moonx cli/sha1sum@0.1.3 -c checksums.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0008-data.md)
