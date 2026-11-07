# tee

Development candidate: `cli/tee@0.2.4`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Copy stdin to files and stdout for MoonX.

```sh
moonx cli/tee@0.2.4 [-ap] [--output-error[=MODE]] [FILE...]
```

## Supported scope

Write each input byte to stdout and every file operand. Select append and output-error behavior explicitly.

## Options

| Option | Description |
| --- | --- |
| `-a, --append` | Append instead of truncating files. |
| `-p` | Ignore pipe errors while reporting other output errors. |
| `--output-error[=MODE]` | Modes: warn, warn-nopipe, exit, exit-nopipe; bare flag selects warn-nopipe. |
| `--help` / `--version` | Show help / package version. |

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Default broken-pipe handling reports unsupported capability with status 2 instead of raising SIGPIPE. Use -p or an explicit error mode.

## Examples

```sh
printf 'hello\n' | moonx cli/tee@0.2.4 output.txt
moonx cli/tee@0.2.4 -a output.txt < extra.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
