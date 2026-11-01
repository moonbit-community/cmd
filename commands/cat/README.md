# cat

Concatenate files and stdin for MoonX.

```sh
moonx cli/cat@0.2.4 [OPTION]... [FILE]...
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

## Limitations

- Visible-byte formatting uses byte rules, not Unicode character rendering.

## Examples

```sh
moonx cli/cat@0.2.4 first.txt second.txt
moonx cli/cat@0.2.4 -n notes.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
