# tree

Published version: `cli/tree@0.1.7`. See the release inventory;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Display directory trees for MoonX.

```sh
moonx cli/tree@0.1.7 [-adfJCnsh] [-L level] [-P pattern] [-I pattern] [-H base] [-T title] [directory ...]
```

## Supported scope

List sorted trees as ASCII text, JSON or HTML, with patterns, depth limits, pruning, sizes and explicit color.

Symbolic links, including dangling links and links to directories, are displayed
as named leaves without reading or following their targets. JSON identifies them
as `link`; text and HTML omit the unavailable `-> target` text. Each selected link
counts as one file. `-d` selects actual directories among discovered children
and excludes their links. An explicit link operand remains a leaf, including
with `-d` (whose report counts directories only). This is a documented subset of upstream
tree's link display, not full target-display or dereferencing compatibility.

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

## Extension and diagnostic contract

Project aliases: --all = -a; --dirs-only = -d; --full-path = -f; --level = -L.
--json = -J; --html = -H; --title = -T; --pattern = -P; --ignore = -I.
--size = -s; --human-readable = -h; --color = -C; --no-color = -n.

See [the finite option and diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics) for the scope and upstream distinction.

## Limitations

- Link target text, ownership, permissions and inode/device reports are unsupported.
- Size modes reject selected links rather than displaying the referent's size.
  Filtered links do not trigger this restriction. Link colors use `ln` (HTML uses
  `LINK`) without classifying referents or dangling targets; `ln=target` is rejected.
- Mode-based text color selectors and HTML executable coloring are unsupported. Directory sizes can fail on platforms without that metadata.
- Names and ordering use C-byte rules; automatic terminal color is unavailable.

## Examples

```sh
moonx cli/tree@0.1.7 -L 2 --noreport project/
moonx cli/tree@0.1.7 -J --noreport project/
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
