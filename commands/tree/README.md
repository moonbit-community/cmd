# tree

Display directory trees for MoonX.

```sh
moonx cli/tree@0.1.5 [-adfJCnsh] [-L level] [-P pattern] [-I pattern] [-H base] [-T title] [directory ...]
```

## Supported scope

List sorted trees as ASCII text, JSON or HTML, with patterns, depth limits, pruning, sizes and explicit color.

## Options

| Option | Description |
| --- | --- |
| `-a, --all / -d, --dirs-only / -f, --full-path` | Include hidden entries / directories only / full paths. |
| `-L, --level=N` | Limit depth. |
| `-P PATTERN / -I PATTERN` | Include files / exclude names and subtrees. |
| `--ignore-case / --matchdirs / --prune` | ASCII-insensitive matching / match directories / prune empty selections. |
| `--filelimit=N / --noreport` | Limit descent by entry count / omit totals. |
| `-J / -H BASE / -T TITLE` | JSON / HTML / HTML title. |
| `-s / -h / --si / --du` | Sizes / binary human sizes / decimal sizes / summed sizes. |
| `-C / -n` | Force color / disable unforced color. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Selected symlinks, ownership, permissions and inode/device reports are unsupported.
- Mode-based text color selectors and HTML executable coloring are unsupported. Directory sizes can fail on platforms without that metadata.
- Names and ordering use C-byte rules; automatic terminal color is unavailable.

## Examples

```sh
moonx cli/tree@0.1.5 -L 2 --noreport project/
moonx cli/tree@0.1.5 -J --noreport project/
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
