# cat

Published version: `cli/cat@0.2.6`. See the release inventory;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Concatenate files and stdin for MoonX.

```sh
moonx cli/cat@0.2.6 [OPTION]... [FILE]...
```

## Supported scope

Copy inputs in order to stdout. With no file, or `-`, read stdin. Formatting continues across file boundaries.

## Options

| Option | Description |
| --- | --- |
| `-n, --number` | Number all lines. |
| `-b, --number-nonblank` | Number nonempty lines; overrides -n. |
| `-s, --squeeze-blank` | Collapse repeated empty lines. |
| `-T, --show-tabs` | Display tabs as ^I. |
| `-E, --show-ends` | Display $ before each newline. |
| `-v, --show-nonprinting` | Display nonprinting bytes visibly. |
| `-A, --show-all` | Equivalent to -vET. |
| `-e / -t` | Equivalent to -vE / -vT. |
| `-u, --unbuffered` | Accepted without changing behavior. |
| `--help` / `--version` | Show help / package version. |

## Extension and diagnostic contract

Project aliases: --show-ends-nonprinting = -e; --show-tabs-nonprinting = -t.
--unbuffered is a project alias of the GNU -u no-op; -h is a project help alias.

See [the finite option and diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics) for the scope and upstream distinction.

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Visible-byte formatting uses byte rules, not Unicode character rendering.

## Examples

```sh
moonx cli/cat@0.2.6 first.txt second.txt
moonx cli/cat@0.2.6 -n notes.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
