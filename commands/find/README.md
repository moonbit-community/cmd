# find

Search directory trees for MoonX.

```sh
moonx cli/find@0.2.3 [PATH...] [EXPRESSION]
```

## Supported scope

Walk without following symbolic links. Combine predicates with negation, AND and OR; print matching paths, execute commands or delete matches.

## Options

| Option | Description |
| --- | --- |
| `-name PATTERN / -path PATTERN` | Match names / paths with shell patterns. |
| `-type / -xtype / -empty / -size` | Test entry type, emptiness or size. |
| `-amin / -atime / -cmin / -ctime / -mmin / -mtime` | Test access, status-change or modification age. |
| `-newer / -anewer / -cnewer / -newerXY / -used` | Compare timestamps; X/Y support a, c and m. |
| `-readable / -writable / -executable` | Test effective access. |
| `-mindepth / -maxdepth / -depth / -prune` | Control traversal. |
| `-print / -print0` | Print newline / NUL-delimited paths. |
| `-exec COMMAND ... ; / +` | Execute per match / in batches. |
| `-delete` | Delete matches in postorder. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Symlink following, ownership/link-target predicates and the complete findutils language are unsupported.
- Only one output/execution action is accepted; -exec must be the final expression action. Birth-time and literal-time selectors are unsupported.

## Examples

```sh
moonx cli/find@0.2.3 . -name '*.mbt'
moonx cli/find@0.2.3 . -type f -maxdepth 2 -print0
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
