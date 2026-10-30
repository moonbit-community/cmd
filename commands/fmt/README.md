# fmt

Reformat text paragraphs for MoonX.

```sh
moonx cli/fmt@0.1.4 [-WIDTH] [-w WIDTH] [-g GOAL] [-suct] [-p PREFIX] [FILE...]
```

## Supported scope

Read files or stdin, preserve indentation and separate paragraphs at blank lines. The default width is 75.

## Options

| Option | Description |
| --- | --- |
| `-w, --width=WIDTH / -WIDTH` | Set maximum width (0 through 2500). |
| `-g, --goal=GOAL` | Set preferred width. |
| `-s, --split-only` | Split long lines without joining input lines. |
| `-u, --uniform-spacing` | Use one inter-word space and two after sentences. |
| `-c, --crown-margin` | Allow a different first-line indent. |
| `-t, --tagged-paragraph` | Preserve hanging indentation. |
| `-p, --prefix=PREFIX` | Reformat matching prefixed lines only. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Uses C-byte columns, not Unicode display widths. A long word can exceed the selected width.
- Does not rewrite input files.

## Examples

```sh
moonx cli/fmt@0.1.4 -w 60 notes.txt
moonx cli/fmt@0.1.4 -s -w 40 notes.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
