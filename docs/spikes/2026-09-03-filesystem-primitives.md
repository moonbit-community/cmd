# Phase 4 Pure-MoonBit Filesystem Primitive Spike

Date: 2026-09-03

## Decision

The normal-file and directory slice for `cp`, `ln`, `mkdir`, `mv`, `rm`,
`rmdir`, `touch`, and `chmod` remains implementable in pure MoonBit and is
covered by destructive tests in disposable directories. The commands do not
delegate to host utilities and the repository adds no C, native stub, or FFI.

Several complete GNU behaviors cannot be represented by the public filesystem
surface in the pinned `moonbitlang/async@0.21.0` dependency. These gaps keep the
affected command rows `partial`; they are not silently approximated. Common
options that require a missing primitive now fail before mutation and explain
the boundary in English.

## Public API evidence

The spike queried the installed dependency with `moon ide doc` and inspected
the locked package sources. The public API provides:

- file kind checks with optional symlink following, regular file I/O and size;
- directory creation/enumeration/removal, path canonicalization and rename;
- symlink creation;
- mtime/atime/ctime reads;
- numeric `chmod` mutation.

No public API was found for hard-link creation, reading a symlink target,
reading current permission bits, owner/group reads or writes, special-file
creation, arbitrary atime/mtime setting, or an `EXDEV` predicate. `OSError`
exposes selected predicates such as `ENOENT`, `EEXIST`, and `EACCES`, but not a
portable cross-device classification.

## Attempted designs

| Missing behavior | Pure-MoonBit approach evaluated | Result and safe behavior |
| --- | --- | --- |
| Hard links | Search the public async filesystem API and locked pure-MoonBit dependencies; consider target-conditioned MoonBit calls. | No callable primitive exists. Reimplementing a filesystem hard link from byte I/O is impossible because inode aliasing is a kernel operation. `ln` without `-s` rejects valid operands before mutation. |
| Symlink preservation and `readlink` | Inspect with `kind(..., follow_symlink=false)`, then recreate with `symlink`. | Kind can identify a link, but its target bytes cannot be recovered. Copying the referent would change semantics and dangling links cannot be represented. `cp` rejects symlink sources rather than following or fabricating them. |
| Metadata preservation and symbolic chmod | Compose mtime/atime reads, numeric `chmod`, and copy I/O. | Current permission bits, ownership and timestamp setters are missing, so `cp -a`/`-p`, `chmod --reference`, and symbolic modes cannot preserve or transform the original metadata. Those paths fail before output mutation. |
| Touch date/reference/selected time | Rewrite an existing file byte to request an mtime update, or create an empty file. | This supports the default common path but cannot set a requested instant, copy a reference timestamp, or select atime versus mtime. `-a`, `-m`, `-d`, `-r`, and `-t` fail before file creation or modification. |
| Cross-device move | Attempt `rename`, then copy and remove on every failure. | Falling back after an unclassified error can overwrite or delete data for permission, path, sharing, or policy failures. Without `EXDEV` and complete metadata/link copying, generic fallback is unsafe. `mv` leaves the source intact when rename fails. |
| Ownership and special files | Encode metadata in regular files or invoke a host helper. | Encoding does not preserve filesystem semantics, and host delegation violates ADR 0001. These remain unimplemented. |

Target-conditioned MoonBit does not unlock unexported platform calls. A native
branch would still need FFI or a runtime API; both are outside this repository's
accepted pure-MoonBit implementation boundary. No suitable pure-MoonBit package
providing these kernel operations was present in the locked dependency graph.

## Observable contract

- Unsupported metadata/timestamp/link options validate their operands and then
  fail before creating, truncating, deleting, renaming, or chmodding a target.
- Recursive copy and removal inspect links without following them.
- Same-filesystem rename remains atomic through the public API; a failed rename
  does not trigger a copy-and-delete fallback.
- Windows keeps explicit symbolic-link and permission capability gates. Linux
  and macOS exercise their native public implementations.
- Repository root/current-directory removal protection remains a documented
  policy difference and cannot be used as evidence of GNU equivalence.

## Follow-up gate

The rows stay `partial`. A future runtime or dependency update may remove a
boundary only after Linux, macOS, Windows, and Wasm tests prove the public API,
side effects, metadata, and failure precedence against the pinned GNU oracle.
The command help and README must continue to state every active weakening.
