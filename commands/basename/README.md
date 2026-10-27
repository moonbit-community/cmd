# basename

Extract path names for MoonX.

```sh
moonx cli/basename@0.2.3 [-a] [-s SUFFIX] [-z] NAME [SUFFIX]
```

## Supported scope

Remove directory components and optionally a suffix. Paths are processed without accessing the filesystem.

## Options

| Option | Description |
| --- | --- |
| `-a, --multiple` | Process each operand separately. |
| `-s, --suffix=SUFFIX` | Remove a matching suffix; implies multiple operands. |
| `-z, --zero` | End each result with NUL. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Suffix removal is literal, not pattern matching.

## Examples

```sh
moonx cli/basename@0.2.3 /tmp/report.txt
moonx cli/basename@0.2.3 -s .txt report.txt notes.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
