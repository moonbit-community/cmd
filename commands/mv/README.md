# mv

This describes version 0.2.2. See the
[support record](../../docs/compatibility.md) for measured option combinations
and backend limits; accepted options do not establish full compatibility.

Move files and directories with the policy-checked atomic rename operation.
Declining an interactive overwrite, including EOF, returns status 1 and leaves
both paths unchanged; other operands are still processed. A no-clobber skip
remains a successful no-op.

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

Same-path moves fail before prompting or making backups, except an explicit
no-clobber/update-none skip. After rename, the source entry must have disappeared;
a same-inode hard-link no-op reports failure and preserves both names. Public
identity metadata is unavailable before the operation. Equal-time targets with
`-i` or `-u` therefore reject explicitly: equal timestamps cannot distinguish
an alias from a separate file. This includes separate files whose mtimes happen
to match. Other processes recreating the source during rename also cause a
postcondition error; no second deletion is attempted.

## Standalone metadata

Standalone `--version` prints exactly `mv 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: mv`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
