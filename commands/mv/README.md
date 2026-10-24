# mv

This describes version 0.2.4. Its unpublished core 0.8.0 dependency reuses a
64 KiB buffer for supported copy fallbacks. See the
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

The async 0.22.5 Native implementation opens Windows symlinks and junctions as
reparse points when renaming them. Wasm imports rename from the installed host,
so the dependency update does not establish that the host contains this fix.
Windows Wasm therefore rejects moving a symlink/junction or backing up a
destination link before prompting or changing paths. No-clobber and update-none
skips still preserve both paths. This does not establish `-u` timestamp-based
skips for links: Windows Wasm rejects those guarded operations before checking
timestamps. Reopen these operations only after a fixed host
is identified and Windows Native/Wasm regressions separately verify the link
and its referent. The file and directory symlink fixtures force real symlinks;
the Windows junction fixture deliberately permits junction creation. Missing
Windows link privileges or observer support are verification failures, not
evidence that the rename behavior works.

Source and destination timestamps describe the directory entries themselves,
so replacing or backing up an existing target also accepts a dangling source
link on verified backends. The Windows scenarios separately exercise Native
link moves and Wasm rejection, comparing link type/target and referent bytes
before and after each operation. Backup-creation failure preserves the fixture
and permits a later valid retry. Restoration after a completed backup is covered
by package-level rename fault injection, including Windows link and junction
backups, their targets and referent bytes. Wasm interactive refusal is checked
with stdin kept open and no bytes sent: it must exit within the observer deadline,
emit no overwrite prompt, and preserve the complete fixture. Replacing a
destination link with a regular source without backup remains allowed on both
backends and has separate Windows command rounds awaiting CI evidence. A real
CLI post-backup failure remains unverified by these fixtures.

Same-path moves fail before prompting or making backups, except an explicit
no-clobber/update-none skip. After rename, the source entry must have disappeared;
a same-inode hard-link no-op reports failure and preserves both names. Public
identity metadata is unavailable before the operation. Equal-time targets with
`-i` or `-u` therefore reject explicitly: equal timestamps cannot distinguish
an alias from a separate file. This includes separate files whose mtimes happen
to match. Other processes recreating the source during rename also cause a
postcondition error; no second deletion is attempted.

## Standalone metadata

Standalone `--version` prints exactly `mv 0.2.4` followed by one
newline. Standalone `--help` starts with `Usage: mv`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
