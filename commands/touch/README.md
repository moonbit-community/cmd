# touch

Development candidate: `cli/touch@0.2.5`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Create missing files for MoonX.

```sh
moonx cli/touch@0.2.5 [-c] [-a|-m] [-d STRING|-r FILE|-t STAMP] FILE...
```

## Supported scope

Create missing files without writing content. Process operands in order; earlier successful creates remain after later failures.

## Options

| Option | Description |
| --- | --- |
| `-c, --no-create` | Skip missing files without creating them. |
| `--help` / `--version` | Show help / package version. |

## Extension and diagnostic contract

Rejection aliases --access-time (-a), --modification-time (-m) and --stamp (-t)
request unavailable timestamp-setting capabilities and fail before mutation.

See [the finite option and diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics) for the scope and upstream distinction.

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Existing files fail even with -c: timestamp updates are unsupported.
- -a, -m, -d, -r, -t and --time are recognized but rejected before mutation.

## Examples

```sh
moonx cli/touch@0.2.5 new-file.txt
moonx cli/touch@0.2.5 -c missing-file.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
