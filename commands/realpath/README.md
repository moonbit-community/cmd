# realpath

Development candidate: `cli/realpath@0.1.5`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Canonicalize paths for MoonX.

```sh
moonx cli/realpath@0.1.5 [OPTION]... NAME...
```

## Supported scope

Resolve paths physically or lexically, with existing/missing component modes and relative output. Default permits a missing final component.

## Options

| Option | Description |
| --- | --- |
| `-e, --canonicalize-existing` | require every component to exist |
| `-E, --canonicalize` | allow a missing final component (default) |
| `-m, --canonicalize-missing` | allow missing or non-directory components |
| `-s, --strip, --no-symlinks` | do not expand symbolic links |
| `--relative-to=DIR` | print relative to DIR |
| `--relative-base=DIR` | use relative output only inside DIR |
| `-q, --quiet` | suppress operand errors |
| `-z, --zero` | terminate output with NUL |
| `--help` / `--version` | Show help / package version. |

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Physical resolution fails when a symbolic link cannot be expanded; -ms processes that spelling lexically.

## Examples

```sh
moonx cli/realpath@0.1.5 -e input.txt
moonx cli/realpath@0.1.5 -ms path/../new.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
