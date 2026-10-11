# MoonBit async public API gaps and upstream feedback

Updated: 2026-10-11

All product commands, shared libraries, test runners, fixtures and automation
must use pure MoonBit. Do not add project-owned C/C++/Rust/JavaScript/TypeScript,
FFI or native stubs, or delegate to host commands to bypass public APIs.
Host tools are allowed only as pinned oracles, test observers, CI setup or
diagnostics. Unsupported operations require explicit rejection, the missing API,
compatibility cost and a testable unlock condition.

## Verified baselines

The 2026-09-21 recheck used released async 0.22.1, x 0.5.5 and moonjq 0.1.2,
with moon/moonrun 0.1.20260920 and moonc/core 0.10.14+7d59c7ec9. Transitive
moonjq dependencies resolved to the same async/x versions. These version claims
are dated observations, not claims about today's registry. Unreleased upstream
main code does not count as available capability.

The 2026-09-26 registry recheck found async **0.22.4**, checksum
`2ffdb85cb229cfe9219161a7f2b959215a79a0d75b7e642cb346713f168a1457`;
0.22.5 was not resolvable. All 50 modules at that baseline resolved 0.22.4 and
passed strict all-target checking. See the
[baseline report](reports/2026-09-26-async-0.22.4-baseline.md).

Async 0.22.4 provides idempotent mkdir options, file/pipe Reader/Writer streams
and streaming gzip Decoder/Encoder interfaces. Parsing, framing, temporary
directory creation and basic gzip integration must use these public facilities,
not remain classified as blocked. Identity, mode readers, readlink, hard links,
handle truncate, isatty, PTY, process groups and exec remain unavailable through
the required public interfaces.

This document proposes API semantics; proposed names are not existing APIs.
Native/Wasm gaps refer to public MoonBit interfaces, not absence of OS or host
capabilities. Source paths are relative to
`.mooncakes/moonbitlang/async/src/`.

## Repair recheck: project solutions do not wait for async

The 2026-10-11 candidate integrates fs.can_execute and corrects strings/column
behavior through released public APIs on Native/Wasm. Terminal-width discovery
still needs isatty/window-size. Local results in the
[repair record](reports/2026-10-11-fidelity-repair/README.md) do not replace
CI or published acceptance for the repair versions.

Further x/time 0.5.5 review found that Zone::from_tzif2 reads only the 32-bit
compatibility block; its name does not establish full 64-bit TZif/DST support.
ZoneOffset::from_seconds(0, ...) returns shared UTC and loses abbreviations such
as GMT. Dublin winter date +%Z in 2038/2050 is a minimal example. These are
x/time implementation behaviors, not host authorization or async read limits.
The candidate shares a bounds-checked pure MoonBit TZif/POSIX decoder and
separate abbreviation lookup between date and diff. Thirty-five coreutils 9.11
timezone calls matched. A released complete TZif v2+ parser with bounds/
truncation checks, future rules and zero-offset abbreviation preservation can
replace this adapter after passing the same regressions.

Released moonjq 0.2.0 fixes tostring/tojson, while an isolated string slice still
returns null. The candidate lowers string slices through public AST Unicode
scalar-array slicing and reconstruction, covering nested filters, negative/open
bounds and type errors. This is project adaptation, not an async blocker.
Remove it when upstream passes the same tests. No dependency-cache edits, FFI
or host jq delegation are used. Keep these new-toolchain results separate from
old 0.2.0 CI and macOS-only evidence; see the historical
[API recheck](reports/2026-09-21-public-api-recheck.md).

A second review found that public rename can succeed on hard-link aliases
without removing the source. The mv candidate checks the postcondition that
the source entry disappeared, reports failure with aliases retained and never
attempts a second deletion. Parent canonicalization detects identical directory
entries early. However, -i/-u decisions precede rename and still need identity.
Equal mtime does not prove identity: the ambiguous equal-time interactive/update
subset explicitly rejects, including separate files with equal times. Unlock
requires public identity/handle metadata and Native/Wasm comparisons.
Concurrent recreation of the source also fails the postcondition without
deleting the recreated entry. This is a specific mv restriction, not a claim that
all mv behavior is impossible. See ADR-0004 and issue #25.

| Priority | Capability | Native / Wasm public status | Classification and effect |
| --- | --- | --- | --- |
| P0 | File identity, handle metadata/truncate | Neither exposes identity/mode/truncate; handles expose kind/size/times | Identity exists internally; faithful existing-inode cp overwrite is blocked |
| P1 | Mode, owner, link count, timestamp setters | Complete interfaces missing; path chmod exists | Metadata readers need expansion; setters unavailable; cp/mv/ls/chmod/touch |
| P1 | Hard links, readlink, handle permissions | Missing; symlink exists | ln and cp/mv link preservation; symlink is not readlink/hardlink |
| P1 | isatty, terminal attributes/window size | No public terminal API; stdio fd is insufficient | sh terminal detection, raw mode, editing/completion/resize |
| P1 | Recoverable signal subscription | Global cancellation signal configuration only | No guarantee of a fresh shell prompt after Ctrl-C |
| P2 | exec, groups, foreground ownership, stopped/continued events, PTY | No complete public chain | exec, fg/bg, job control, terminal children and complete timeout |

## P0: identity and operations on the same handle

Target: open source/destination, compare stable identities, then truncate and
write through the same distinct destination handle, preserving the existing
inode and hard links. New files also require source mode and umask semantics.

Public fs/File methods expose kind, size, times, position, seek and read/write,
but no identity, mode/metadata or truncate. File::fd is public, with Unix OS fd,
Windows HANDLE and opaque Wasm UInt64 host-resource representations; the latter
must not be used as a Linux /proc/self/fd number. CreateOrTruncate truncates
during open, before callers can compare identity.

Internally, event_loop defines/uses FileIdentity, including watch; Native
statx/fstatx paths and Wasm host imports exist. The accurate classification is
**internal identity is not public**, not “Wasm has no inode capability.”

Minimal behavior probe: the workspace filesystem-fidelity scenario creates a
source, uses a host ln fixture to create a hard-link alias, runs cp source alias
and observes both contents. Product code never invokes host cp/ln.
An old published version returned 0 and cleared a 17-byte source. Native/Wasm
candidates reject nonzero and preserve contents; cp --no-preserve=mode source
new succeeds on both. Rejection is a temporary strict subset, not implemented
GNU overwrite semantics.

Suggested public API: opaque comparable FileIdentity; File.metadata() returning
identity/mode/kind/size; File.truncate(length) operating on the open object.
Define device/volume scope, lifetime, nofollow, races and permission failures.
Unlock requires released APIs and tests for same-file/hard links, concurrent
replacement, ordinary overwrite, new-file mode and retained destination inode.
realpath and temporary-file rename are not substitutes. See ADR-0004.

Alternative research: Linux Native could derive identity from fdinfo inode/
mount ID plus mountinfo device number, then reopen the held object through
/proc/self/fd/<fd>. This is not cross-backend and still lacks source mode.
macOS has no procfs; bind-mount, replacement-race and permission failures were
not validated on Linux, so overwrite remains closed. See the recheck for
required probes. (mnt_id, ino) is not (device, ino); contents, realpath and
advisory locks are not identity.

## P1: metadata, times, links and permissions

Public fs provides path/handle atime/mtime/ctime readers, path chmod, symlink
and rename. It lacks mode/uid/gid/nlink readers, utime, readlink, hardlink and
handle chmod; x/fs does not fill these gaps. Access queries answer only current
credentials, not mode bits. realpath loses relative link text and dangling
targets. Windows chmod is a public entrypoint with unsupported runtime behavior,
a different category from no public entrypoint.

Minimal probe: filesystem-fidelity records an existing file's mtime/bytes, runs
touch existing and verifies nonzero with both unchanged. touch new and touch -c
absent succeed on Native/Wasm. This proves no fabricated timestamp update; it
is not an upstream setter failing at runtime.

Suggested semantics: explicit atime/mtime Now, Omit and nanosecond values with
follow_symlink, for paths and handles; metadata includes permissions/kind/link
count/identity; hard_link/read_link never silently copy contents; handle chmod
does not resolve the pathname again. The filesystem controls ctime; do not
invent an arbitrary ctime setter.

Costs include ordinary cp source modes, cp -p/-a, faithful cross-device mv,
ls long format, incremental chmod, existing-file touch and hard links.
Unlock each operation only after released APIs and differential permission,
timestamp-precision, link-relation and failure-effect tests.

EXDEV is no longer an absolute blocker: @async.platform identifies actual
Linux/MacOS/Windows, and POSIX OSError(18, ...) is classifiable through
core/platform.is_cross_device_error. Windows error domains need separate runtime
evidence; do not apply POSIX errno there. Recognizing EXDEV alone cannot make a
metadata/link/time-losing mv fallback faithful.

## P1: terminals and signals beyond line interaction

stdio exposes Input/Output and fd, but not isatty, termios/raw mode or window
size/events. signal exposes set_global_cancellation_signals for INT/TERM/HUP/BREAK.
A character device can be /dev/null, so kind is not TTY detection; descriptors
alone are not terminal control.

Minimal runnable probe: sh-interactive-session keeps child stdin open, waits for
stderr prompts/stdout and sends multiline commands, read, a pure MoonBit
foreground line-reader, syntax errors and EOF. It passes on Native/Wasm and
establishes the implementable line REPL. Advanced verification needs real
terminal attributes, resize and the next prompt after Ctrl-C. No public
subscription API currently satisfies that test; no such pass is claimed, and
invented API names are not runtime-failure evidence.

Suggested APIs: isatty(stream), attribute read/restore, scoped raw mode,
window size/events and subscriptions routing SIGINT to the foreground task
while the shell session remains active to wait/clean up/continue. Specify
subscription/global-cancellation precedence and restoration.
handle_cancellation performs cleanup but cannot undo task cancellation; adding
catch does not restore the REPL. Unlock requires a released API and real-terminal
acceptance.

## P2: process replacement and job control

process exposes spawn, collect_output, wait, cancellation and pipes, without
exec, process-group get/set, foreground-terminal ownership, stopped/continued
wait events or PTY. Native low-level fds do not expose those missing operations.

Minimal probe: sh -c 'exec printf x' explicitly rejects. It neither looks up an
executable named exec nor substitutes spawn+wait for PID/signal/status/fd
inheritance. Ordinary calls and pipes still use public process APIs; fg/bg
cannot be accepted without terminal-group APIs.

Suggested operations must separately express replace-current-process,
create/join groups, group signals, foreground ownership, Exit/Stopped/Continued
wait events and PTY master/slave close rules. Define cancellation scope and
wait/reap ownership to prevent zombies or hung pipe draining.

Public CancellationHandler function values were also checked. Native
hard_cancel invokes kill but discards its result. The macOS
[negative probe](reports/2026-09-21-api-probes/cancellation-is-not-kill.mbtx)
returns Unit for a PID the host confirms nonexistent. graceful_cancel later
escalates to SIGKILL and is not one-shot signal delivery. Suggest send_signal
with OSError/permission/nonexistence feedback. Internal kill does not make a
complete kill command available, nor does this imply no low-level signal
capability. Unlock requires each backend's public chain plus direct-child,
descendant, stop/resume, terminal Ctrl-C and post-cancellation reaping tests;
one disappearing PID is insufficient.

## Project work that must not be blamed on async

The 2026-10-11 audit found which@0.1.0 checking only kind and succeeding on mode
0644. Public fs.can_execute returned false for the same macOS fixture while
Native/Wasm/exact MoonX which returned 0. This was missing integration, not a
mode-reader blocker. The repair now uses access checks and separately defines
Windows PATHEXT. Mode readers remain a real cp/chmod gap; access cannot recover
mode bits.

Column defaults/final LF/layout, strings radix/encoding/TAB, date TZ handling
and multiple-file rev/tac are project work. Date can adapt public x/time/TZif;
only setting the clock needs a setter. tac regex and nl pBRE can adapt core/bytere.
Tree JSON/HTML/filters/explicit colors are independent of readlink/mode.
The original [audit](reports/2026-10-11-command-followups/README.md) did not
implement these corrections; the later repair status is separate. See the
[79-command register](command-followups.md).

### Gzip codec workaround, 2026-10-10

Async 0.22.4 gzip.Decoder handles one member without optional headers. CRC or
truncated-trailer errors during a read can hide bytes already produced in that
read. MemoryReader can help locate members but cannot recover hidden output.
This affects Native/Wasm and is not host denial.

core/gzipops implements RFC 1951 stored/fixed/dynamic Huffman decoding, a 32 KiB
window and overlapping backreferences in pure MoonBit, while reusing the public
Encoder. Optional fields, header CRC, concatenated members, payload CRC/size
and failure prefixes are handled locally; gzip framing is no longer a blocker.
For gzip -dc input `1f8b08000000000000034b4c4a0600c2412435`, expected output is
abc followed by status 1. The candidate fixes that contract; the upstream small
buffer path had delivered only a. Regressions: core/gzipops/codec_wbtest.mbt;
[GNU gzip 1.14 comparisons](reports/2026-10-10-gzip-oracle.mbtx).

Upstream could support RFC 1952 optional headers/continuous members and defer
errors until produced bytes have been delivered, or include partial bytes in an
error. A released decoder passing the same regressions would remove the local
maintenance need. Full compressed-input buffering and streaming-memory
improvement remain project work.

### Patch and split outputs have different inode contracts

Ordinary patch writeback may replace an inode through rename; cp's retained-inode
requirement does not apply. The blocker is source metadata/mode preservation,
also required by -o new. Ordinary update/named output reject; -o -, --dry-run
and explicit creation/deletion work. See [macOS inode/mode observations](reports/2026-10-10-patch-file-semantics.md),
which are not full GNU/Linux certification. Released metadata plus safe
replacement and pinned GNU metadata comparisons unlock the restriction.
split/csplit exclusively create new outputs; existing outputs reject without
identity/handle-truncate to avoid clearing an input hard link. Suffixes, regex
splitting, cleanup and patch context/unified parsing are project responsibilities.

### Resolved: explicit curl Cookie plus jar

Earlier review examined one Map and missed independent public Client(headers=...)
and Client::request(extra_headers=...) layers. Async 0.22.4 emits client fields
then request fields. A pure MoonBit [raw TCP probe](reports/2026-09-21-api-probes/http-header-layers.mbtx)
observed two Cookie fields in the same order as macOS curl 8.7.1. Wget 1.25.0
sends only the explicit field and retains it across origins; curl removes it,
also confirmed by raw TCP. Workspace implementations cover bytes, same/cross
origin redirects and real CLI; published 0.2.0 does not include the correction.
There is no CRLF injection, internal import, transport replacement or FFI.
This combination is no longer an upstream blocker.

Two Maps still cannot express arbitrary ordered duplicate fields, so this does
not establish full repeated -H fidelity. An ordered header list remains useful
for that narrower gap. Response.cookies already preserves multiple Set-Cookie
fields. PSL/IDNA/cookie-prefix rules remain project work.

Shell parsing/quoting/splitting/glob, JSON framing/AST bindings, cookies and make
DAG scheduling are project implementation. Remaining GNU BRE/ERE extensions,
full shell printf/test, backticks and arithmetic assignment belong to project
or interpreter adaptation; this table must not permanently exclude feasible work.

Host denial is a third category: record the authorization policy, original
error and status when a public operation is denied. It is neither missing API
nor missing runtime implementation. Official dependencies may supply their
underlying runtime; the project adds no C/Rust/JS/FFI.
