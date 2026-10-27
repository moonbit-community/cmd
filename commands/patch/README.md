# patch

Apply unified and context patches for MoonX.

```sh
moonx cli/patch@0.2.1 [OPTION]... [ORIGINALFILE [PATCHFILE]]
```

## Supported scope

Check patches with offsets, fuzz and reversal. Supports creating/deleting files and writing patched existing-file content to stdout.

## Options

| Option | Description |
| --- | --- |
| `-p, --strip=N` | remove N leading file-name components |
| `-i, --input=FILE` | read the patch from FILE instead of stdin |
| `-o, --output=-` | write patched files to stdout |
| `-r, --reject-file=FILE` | write rejected hunks to a new FILE; - discards |
| `-d, --directory=DIR` | resolve target paths relative to DIR |
| `-R, --reverse` | apply additions as removals and vice versa |
| `--dry-run` | check without writing or deleting files |
| `-s, --quiet` | suppress routine file messages |
| `-u, --unified` | require unified input |
| `-c, --context` | require context input |
| `-t, --batch` | select a detected reverse without prompting |
| `-F, --fuzz=N` | ignore up to N outer context lines (default 2) |
| `--no-backup-if-mismatch` | accept the no-backup strict profile |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Updating existing pathnames and named -o output are rejected; use --dry-run or -o -.
- Binary/mode/rename patches, backups and interactive reversal prompts are unsupported. Existing reject files are never overwritten.
- Exit 1 for rejected hunks and 2 for malformed, unsupported or fatal requests.

## Examples

```sh
moonx cli/patch@0.2.1 --dry-run -i change.diff
moonx cli/patch@0.2.1 -o - -i change.diff original.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
