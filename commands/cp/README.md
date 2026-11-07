# cp

Development candidate: `cli/cp@0.2.5`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Copy files and directories for MoonX.

```sh
moonx cli/cp@0.2.5 [--no-preserve=mode] [-R] [-H|-L|-P] [-f|-i|-n] [-u|--update=MODE] [-b|--backup[=CONTROL]] [-S SUFFIX] [-T] [-v] SOURCE... DEST
```

## Supported scope

Copy to new destinations with `--no-preserve=mode`. Add `-R` for directory trees. Skip modes can succeed without copying.

Supported copies use one shared tree preflight followed by execution. Preflight
rejects unsupported descendants before creating any destination; actual file
creation remains exclusive. Reusing an existing empty directory reports no copy.

## Options

| Option | Description |
| --- | --- |
| `--no-preserve=mode` | Required for copying to a new destination. |
| `-R, -r, --recursive` | Copy directory trees. |
| `-H / -L / -P` | Select source-link traversal. |
| `-n, --no-clobber` | Skip existing targets. |
| `-u, --update[=MODE]` | Update selection: all, older, none or none-fail. |
| `-T, --no-target-directory` | Treat destination as a complete path. |
| `-v, --verbose` | Show copied paths. |
| `--help` / `--version` | Show help / package version. |

## Extension and diagnostic contract

Project alias: --dereference-command-line selects -H; GNU cp exposes only the short spelling.

See [the finite option and diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics) for the scope and upstream distinction.

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.
Option values and operands after -- remain literal during alias normalization.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Default mode-preserving copies, archive/preserve modes and existing-file replacement are unsupported.
- -f/-i, -b/--backup and -S are parsed but do not enable overwrite, prompts or backups.
- Recursive links require an enabled traversal mode; cycles and destinations nested inside the source are rejected.

## Examples

```sh
moonx cli/cp@0.2.5 --no-preserve=mode source.txt new.txt
moonx cli/cp@0.2.5 --no-preserve=mode -R source-dir new-dir
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
