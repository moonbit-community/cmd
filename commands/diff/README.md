# diff

Compare files and directories for MoonX.

```sh
moonx cli/diff@0.2.2 [-qsauciwbBZrN] [-U LINES | -C LINES] [--label LABEL] FILE1 FILE2
```

## Supported scope

Produce normal, unified or context differences. One input may be stdin. Exit 0 for equal inputs, 1 for differences and 2 for errors.

## Options

| Option | Description |
| --- | --- |
| `-q / -s` | Report differences briefly / report equal files. |
| `-u, -U LINES / -c, -C LINES` | Select unified / context output. |
| `--label LABEL` | Override a header label. |
| `-a` | Treat binary data as text. |
| `-i / -w / -b / -Z / -B` | Ignore ASCII case / whitespace / whitespace amount / trailing whitespace / blank-only changes. |
| `--strip-trailing-cr` | Remove one CR before each LF. |
| `-r / -N` | Recurse / treat missing files as empty. |
| `--unidirectional-new-file` | Treat missing files as empty on the left only. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Locale collation and comparing symbolic-link target text are unsupported.
- Large comparisons retain complete inputs in memory.

## Examples

```sh
moonx cli/diff@0.2.2 -u old.txt new.txt
moonx cli/diff@0.2.2 -r old-dir new-dir
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
