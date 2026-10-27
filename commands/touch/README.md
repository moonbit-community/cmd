# touch

Create missing files for MoonX.

```sh
moonx cli/touch@0.2.3 [-c] [-a|-m] [-d STRING|-r FILE|-t STAMP] FILE...
```

## Supported scope

Create missing files without writing content. Process operands in order; earlier successful creates remain after later failures.

## Options

| Option | Description |
| --- | --- |
| `-c, --no-create` | Skip missing files without creating them. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Existing files fail even with -c: timestamp updates are unsupported.
- -a, -m, -d, -r, -t and --time are recognized but rejected before mutation.

## Examples

```sh
moonx cli/touch@0.2.3 new-file.txt
moonx cli/touch@0.2.3 -c missing-file.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
