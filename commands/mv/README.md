# mv

This describes version 0.2.0. See the
[support record](../../docs/compatibility.md) for measured option combinations
and backend limits; accepted options do not establish full compatibility.

Move files and directories with the policy-checked atomic rename operation.
Supports force/no-clobber/interactive selection (`-f`/`-n`/`-i`), update modes
(`-u`/`--update`), backup controls (`-b`/`--backup`, `-S`), explicit target
paths (`-T`), directory destinations, and verbose output. Cross-filesystem
copy-and-delete fallback is excluded because public APIs cannot preserve all
required mode/link/time semantics. POSIX EXDEV can now be classified using
async 0.22.4 host-platform information. The source remains intact when rename
or backup commit fails.
Classification of EXDEV does not add a cross-device fallback. Windows rename
error classification and the remaining interactive/backup/update combinations
still need independent validation.
