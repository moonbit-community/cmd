# mkdir

Development candidate: `cli/mkdir@0.2.7`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Create directories for MoonX.

```sh
moonx cli/mkdir@0.2.7 [-p] [-m MODE] [-v] DIRECTORY...
```

## Supported scope

Create multiple directories and optional parents. Failed operands do not stop later attempts; -p preserves existing directory modes.

Symbolic leaf modes follow the host's directory creation behavior. For a
sticky-only `+t`, GNU's creation and permission-adjustment sequence yields
`1755` on Linux and `1777` on macOS; explicitly assigning `a=rwx,+t` yields
`1777` on both. Set-group-ID may be cleared when the caller does not belong
to the inherited directory group.

## Options

| Option | Description |
| --- | --- |
| `-p, --parents` | Create missing parent directories. |
| `-m, --mode=MODE` | Set the leaf mode, numeric or supported symbolic. |
| `-v, --verbose` | Show created directories. |
| `--help` / `--version` | Show help / package version. |

## Argument and exit-status contract

Ordinary option/operand errors exit 1; capability refusals exit 2. During
multi-operand execution a capability failure takes precedence over status 1,
and later operands are still attempted.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Symbolic modes whose result depends on the current umask are rejected before creation.
- A new POSIX parent that fails public write/search checks causes status 2. Already-created parents remain, and verbose output records their creation. No guessed chmod mask is applied.
- These access checks cannot recover raw mode or umask. Passing them under elevated privileges or ACLs does not establish GNU owner-bit or complete parent-mode parity. Restrictive parent umasks remain outside that supported permission profile, including when creation succeeds.
- Windows numeric and symbolic `-m` setters reject before any new path is created. `-p` with all requested directories already present remains a successful no-op.

## Examples

```sh
moonx cli/mkdir@0.2.7 -p output/reports
moonx cli/mkdir@0.2.7 -m 700 private-dir
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
