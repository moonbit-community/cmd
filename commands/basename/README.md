# basename

Published version: `cli/basename@0.2.5`. See the release inventory;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Extract path names for MoonX.

```sh
moonx cli/basename@0.2.5 [-a] [-s SUFFIX] [-z] NAME [SUFFIX]
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

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Suffix removal is literal, not pattern matching.

## Examples

```sh
moonx cli/basename@0.2.5 /tmp/report.txt
moonx cli/basename@0.2.5 -s .txt report.txt notes.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
