# fold

Wrap text lines for MoonX.

```sh
moonx cli/fold@0.1.3 [OPTION]... [FILE]...
```

## Supported scope

Wrap files or stdin at 80 columns by default, preserving bytes and an unterminated final line.

## Options

| Option | Description |
| --- | --- |
| `-b, --bytes` | count bytes rather than columns |
| `-c, --characters` | count characters in the C-locale byte profile |
| `-s, --spaces` | break after the last available blank |
| `-w, --width=WIDTH` | use WIDTH columns instead of 80 |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Character and display-width modes use the C-byte profile; multibyte Unicode counting is unsupported.

## Examples

```sh
moonx cli/fold@0.1.3 -w 72 notes.txt
moonx cli/fold@0.1.3 -s -w 40 notes.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
