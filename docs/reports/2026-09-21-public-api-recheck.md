# Filesystem, terminal and process public API recheck

Date: 2026-09-21
Language revision: 2026-10-11; historical results retained.

This record reviews downloaded stable async 0.22.1, x 0.5.5 and the toolchain's
public standard-library interfaces. The toolchain was upgraded to moon/moonrun
0.1.20260920 and moonc 0.10.14+7d59c7ec9. These are API findings and testable
directions, not new command compatibility results. Existing 0.2.0 runtime
evidence is recorded separately.

## Conclusions

`File::fd` **is public**, but that does not expose arbitrary OS fd operations
on every backend. `types/types.mbt` distinguishes Unix Native OS Int fds,
Windows Native opaque HANDLEs and Wasm opaque UInt64 host-resource handles.
A generated `pkg.generated.mbti` reflects its generating platform; an Int
signature alone cannot establish the Wasm representation. `raw_fd` is
explicitly Native-only and exposes ownership transfer, reading, writing and
closing, without stat, truncate, ioctl or exec.

| Target | Public entrypoints | Finding |
| --- | --- | --- |
| Identity | File::fd, kind, length, timestamps | Identity exists internally but has no public getter. Linux Native procfs is a conditional research direction below. |
| Mode / owner / nlink | Path chmod and can_read/write/execute | Access answers whether current credentials can access a file; it cannot recover owner/group/other bits, setid, sticky or ACLs for faithful mode copying. |
| Truncate an open object | TruncateExisting / CreateOrTruncate at open | No handle truncate. Reopening the original pathname races; a Linux procfs fd path requires separate validation. |
| Set timestamps | atime/mtime/ctime readers | No setter. Rewriting bytes, empty writes or reading cannot express specified times, Now/Omit or follow/no-follow. |
| readlink | realpath, symlink | realpath resolves to an absolute endpoint, losing relative link text and failing to preserve dangling-link/loop semantics. |
| Hard link | symlink, rename | Neither creates a second name for the same inode; copying bytes is not equivalent. |
| isatty / termios / resize | stdio fd, Native raw_fd | No ioctl/termios/isatty. Character-device kind, TERM or opening /dev/tty cannot establish that a particular stdin/stdout is a terminal. |
| Recoverable SIGINT | Global cancellation signal set, task cancellation | Signal selection is available, but not subscriptions routing SIGINT only to the foreground task. Cleanup does not undo task cancellation. |
| exec / job control | spawn, wait, direct-child cancellation | No process replacement, groups, foreground-terminal ownership, stopped/continued events or PTY. Spawn+wait cannot preserve PID/signal semantics. |

Missing means absent from these released public interfaces, not absent from the
OS or Wasm host. Windows path chmod is a different category: the public function
exists, but released source explicitly documents unsupported behavior and errors.

## Linux Native procfs: testable, not yet supported

Linux documents `ino` and `mnt_id` in `/proc/self/fdinfo/<fd>`, plus mount IDs
and major:minor in `/proc/self/mountinfo`. Pure MoonBit could read and parse
these with File::fd/read_file to obtain an open object's (st_dev, inode).
Using (mnt_id, inode) alone is wrong: bind mounts can assign different mount IDs
to one file. See [Linux procfs](https://docs.kernel.org/filesystems/proc.html).

`/proc/self/fd/<fd>` refers to an open file instead of looking up the original
pathname again. Reopening that object while holding the handle is a research
direction; permissions are still rechecked and accessible procfs is required.
See [proc_pid_fd](https://man7.org/linux/man-pages/man5/proc_pid_fd.5.html).

A pure MoonBit probe must at least verify:

1. Two opens of one pathname, hard-link aliases and different-file identities.
2. Bind-mount aliases of one inode; mount ID must not substitute for device ID.
3. Open a destination, move its pathname and replace that path with another
   file, then truncate through the fd path. Only the original open object and
   its hard links may change; the replacement path must remain intact.
4. Reject before writing when procfs is unavailable/denied, fdinfo lacks fields
   or mountinfo has no corresponding mount.
5. Test Native independently. **Never insert opaque Wasm resource handles into
   procfs paths.**

Even successful evidence would unlock only a conditional Linux Native overwrite
subset. Source mode for ordinary new-file cp and time/owner/link preservation
would remain unresolved. This review ran on macOS; `docker info` returned
`command not found`. No Linux runtime result or relaxed product boundary was
claimed.

## Rejected substitutes

- **Advisory locks as identity:** conflicts may come from another process and
  semantics vary by OS/filesystem. try_lock's Bool is not unambiguous identity;
  one alias fixture does not establish safe general overwriting.
- **Buffer source, then truncate:** this may reduce one corruption mode but
  still turns an expected `cp file alias` failure into success and does not
  establish identity or permissions.
- **Mutate chmod to infer the original mode:** probing changes the observed
  object and cannot reliably restore permissions, ctime or ACLs. Access queries
  are not mode-bit readers.
- **realpath as readlink or identity:** it loses link text and misses hard links.
- **Wrap the entire REPL in protect_from_cancel:** cancellation shielding is
  not recoverable signal subscription and cannot guarantee foreground-command
  termination followed by the next prompt after every Ctrl-C.
- **Reinvoke async's hidden main:** integration.mbt documents run_async_main
  as a toolchain entrypoint that must not be called directly; its SIGINT path
  terminates the process by signal. It is not a public session-recovery API.
- **Import internal/event_loop or add FFI:** both violate the public-API and
  no-project-FFI boundary, even if a compiler could reach the implementation.
- **Unwrap CancellationHandler as kill:** Native does invoke kill but returns
  Unit and discards errors at process/unix.c:144. The macOS
  [probe](2026-09-21-api-probes/cancellation-is-not-kill.mbtx) confirmed host
  `kill -0` rejects a nonexistent PID while hard_cancel returns normally.
  Missing failure feedback and arbitrary one-shot signals prevent reliable
  command status. graceful_cancel's later SIGKILL is not one TERM. This path
  was tested and rejected for semantic reasons.

## Released source evidence

Paths below are relative to async 0.22.1 `.mooncakes/moonbitlang/async/src/`.

| Location | Evidence |
| --- | --- |
| fs/pkg.generated.mbti:10, :80 | Full path/File public methods: fd, locks and positioned I/O; no metadata, set-times or truncate |
| fs/file.mbt:109 | Public open discards internally returned identity |
| internal/event_loop/fs.mbt:17, :35 | Internal FileIdentity { dev_id, file_id }; open also obtains identity |
| types/types.mbt:16 | Distinct Wasm opaque handle, Windows HANDLE and Unix fd |
| raw_fd/moon.pkg, raw_fd/pkg.generated.mbti | Native-only read/write/close |
| fs/utils.mbt:82, :121, :148 | Access, realpath and unsupported Windows chmod |
| stdio/pkg.generated.mbti | Descriptors and Reader/Writer, no terminal control |
| signal/pkg.generated.mbti, async.mbt:50 | Global cancellation configuration; handle_cancellation does not clear cancellation |
| process/pkg.generated.mbti | Spawn/wait/cancel/redirection, no exec/job control |
| integration.mbt:16, integration.wasm.mbt:18 | Hidden toolchain entrypoints terminate after global signals |

x 0.5.5 fs exposes basic directory and whole-file I/O; sys exposes exit and
deprecated environment/argv APIs. Standard-library public interfaces do not
supply the missing OS operations. Native C and Wasm host imports were inspected
only to identify capability layers; no project FFI was introduced.
