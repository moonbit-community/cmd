# ADR-0004: Maximum Correct Filesystem Subset

Status: Accepted
Date: 2026-09-05
Updated: 2026-11-08

## Decision

Implement each operation's correct subset through released public MoonBit APIs.
Do not infer inode identity from paths, timestamps or content, use rename as
inode-preserving overwrite, or rewrite content to simulate touch. Public async
0.22.7 lacks the identity, raw mode, handle truncation, timestamp-setting,
hard-link and readlink operations required by the boundaries below. Host
observers, private APIs and FFI do not expand the product's capabilities.

## Mutation and identity boundaries

Serve decodes URL paths once and rejects traversal, invalid UTF-8, control bytes
and Windows path aliases before filesystem access. Canonical file/index targets
must remain inside the canonical service root with a component boundary;
only regular files are opened. Launcher-supplied Wasm policy can separately
grant root-only reads and loopback bind, without writes or outbound connections.
It does not replace URL containment checks when the caller grants broader reads.
Path canonicalization and open remain separate operations: released async 0.22.7
does not provide descriptor-relative confined opening on Wasm, and the current
host policy does not establish race-free filesystem isolation. Hostile concurrent
replacement is an explicit unsupported boundary. Reopen this decision when a
released public Wasm API and host provide confined descriptor-relative opens;
require concurrent symlink/ancestor replacement regressions before expanding the
claim. [Serve scenarios](../../tests/scenarios/serve.mbt) test exact file/MIME
responses, encoded traversal, POSIX outside-root links, and restrictive policy.

Rmdir's ignore-nonempty policy classifies a failed removal, rather than reading
a directory first and reporting simulated success. Typed OSError values identify
ENOTEMPTY (Linux 39, macOS 66, Windows 145) and EEXIST. GNU's additional
permission/busy/read-only cases are ignored only after observing a real,
non-followed directory with entries. Regular files, missing paths and directory
symlinks retain failure on POSIX. Windows follows the actual public removal
result: [RemoveDirectoryW](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-removedirectoryw)
can remove a junction itself while preserving its nonempty referent. The Windows
junction cases assert that distinct platform contract. Parent removal stops on the first failed/ignored child,
and verbose messages precede each attempted syscall. The local removal tests
and tests/cases/rmdir.json assert both status and retained paths; POSIX link
fixtures are platform-scoped. These pathname observations do not eliminate
concurrent replacement races. Stronger guarantees require public handle-relative
directory operations supported on Wasm, plus race regressions.

| Operation | Supported behavior and deliberate limit | Condition for expansion |
| --- | --- | --- |
| cp | New destinations with --no-preserve=mode follow umask. Default preservation and existing-file overwrite refuse; no-clobber/update skips remain. | Public mode, identity and handle operations; alias and partial-effect tests |
| mv | Rename entries with ordered backup/prompt/update effects. Do not delete a remaining source to manufacture success; EXDEV has no copy/delete fallback. Ambiguous equal-time interactive/older-only cases refuse. | Identity and metadata-preserving fallback; link, time, mode and race tests |
| touch | Create missing files; -c skips missing files. Existing timestamp updates refuse without changing content. | Public timestamp setter and preserved-content observations |
| patch | Offset/fuzz, mixed hunk results, new rejects, stdout/dry-run and selected create/delete. Existing target, named-output and reject replacement refuse. | Mode-preserving replacement and safe reject identity/truncation |
| sort output | Ordinary sort consumes inputs before truncating an existing target, preserving inode/mode. Streaming merge refuses an existing output. | Safe identity/truncation or a sound alias/late-read-error algorithm |
| split/csplit | Exclusively create pieces; never truncate collisions or remove pre-existing names. | Handle identity/truncation and alias evidence |
| xxd output | Exclusively create outputs; positioned reverse writes are supported. Existing outputs refuse. | Identity/handle/mode operations and backpatch failure tests |

Rm inspects the final entry without trailing separators before recursion.
A symlink there rejects with status 1, including force mode, preserving link
and target. Concurrent pathname replacement remains a handle-relative identity
limit. Final dot/dot-dot and root protection follow [ADR-0002](0002-policy.md).

Interactive ln/mv overwrite refusal, including EOF, returns failure, preserves
paths and continues remaining operands. No-clobber/update skips are successful
no-ops. The last ln -f/-i selector wins. Mv timestamp decisions do not follow
symlinks, including dangling entries.

The unpublished ln/mv backup repair scans sibling names once and chooses the
version after the highest valid `NAME.~N~`, where N is positive decimal without
leading zeroes. Compare and increment digits as strings to avoid machine-integer
overflow. Existing mode uses a simple suffix only when no valid numbered name
exists; failed directory scans remain filesystem errors. Simple and disabled
modes do not scan. Shared tests cover gaps, malformed names, hidden entries,
directory entries and long versions; CLI cases assert preserved backup contents,
the new destination and source removal/retention. Linux CI compares the gap cases
against the pinned oracle. Name-length limits and concurrent pathname changes
retain filesystem errors and do not establish a handle-relative race guarantee.
The selected mode carries its replacement policy independently of suffix text:
numbered backups, including existing-numbered mode, never replace a backup that
appears after selection. A deterministic private rename injection asserts the
collision error and preserved original/competing contents. Simple suffixes still
replace their previous backup, even when spelled like a numbered name.
Nonliteral sibling basenames are confirmed through the operand-derived backup
path, so actual case/Unicode aliases count without folding distinct names on a
sensitive filesystem. Only larger versions need this extra metadata lookup.
An oversized constructed nonliteral probe cannot name an existing backup;
propagate all other lookup errors and every scan/real rename failure. The
released public `OSError(Int32, context)` exposes the host error code, classified
locally using Linux [ENAMETOOLONG 36](https://github.com/torvalds/linux/blob/master/include/uapi/asm-generic/errno.h),
Darwin [ENAMETOOLONG 63](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/errno.h),
and Windows [ERROR_FILENAME_EXCED_RANGE 206](https://learn.microsoft.com/en-us/windows/win32/debug/system-error-codes--0-499-).
Replace these private constants when a released named predicate is available.
Actual Wasm oversized-name tests observe the host code; not-found results remain
distinct from an observed name-too-long result. This is not an error-message
parser or a host implementation of the command. Alias tests observe the volume
before asserting either shared or distinct-name behavior. No timing acceptance
is claimed for the additional metadata lookups.

Ln preserves the original creation error after successful backup restoration.
When restoration also fails, it reports both errors with the destination and
backup paths. The diagnostic describes the attempted recovery without claiming
that either path necessarily retains its old contents. Private injected-runtime
tests in [ln/recovery_wbtest.mbt](../../commands/ln/recovery_wbtest.mbt) perform
real backups and assert successful restoration, recovery failures both before
and after mutation, and exact diagnostics. Rollback stays cancellable because
cancellation may follow a committed creation; an acknowledged-commit test checks
that the new entry and backup survive. POSIX checks a real symlink; Windows uses
an injected file commit to test cancellation ownership and makes no link-support
claim. This is an unpublished diagnostic repair, not a stronger filesystem
transaction guarantee. Reconsider cancellation rollback only with a public API
that establishes commit state and handle-relative identity.

Windows Wasm source symlink/junction moves and destination-link backups reject
before prompting or mutation. No-clobber/update-none skips remain; regular
sources replacing destination links without backup have separate positive
tests. Lift the restriction only with a released fixed Wasm host and actual
link, junction, backup and referent tests; a Native fix is insufficient.
Missing link privileges/observers fail the fixture. See
[issue #38](https://github.com/moonbit-community/cmd/issues/38).

## Paths, modes and display

| Area | Current choice and limitation |
| --- | --- |
| realpath | Public physical resolution; lexical -m/-s and relative-to/base rules. Windows physical modes expand existing 8.3 aliases; lexical modes preserve spelling. Unresolved link targets need readlink. |
| rg | Normalize internal Windows separators, retain drive boundaries and detect followed loops through canonical ancestors. Device identity, redirected-stdout identity, raw invalid-UTF-8 paths and missing creation times remain limits; no invented dev/ino zero. |
| mkdir/chmod | Numeric chmod follows operand links and skips recursively encountered links. Mkdir applies leaf modes and accepts mask-independent omitted-who results. Parent-mode, temporary-owner and unavailable Windows setter cases remain narrow limits. |
| rm | Explicit -i/-I uses original operand-count/recursive rules and a byte reader. Automatic write-protect prompting needs terminal state and raw permissions. |
| ls | Selected layouts, quoting, ordering and explicit colors use actual metadata. Execute access does not substitute for mode bits; automatic color needs terminal detection. |
| tree | Iterative traversal and postorder totals use actual metadata. Links are named leaves, never traversed, and count as files; -d selects actual child directories while retaining explicit operands. JSON preserves link type and HTML link color. Target text needs readlink. Selected-link sizes retain the project's explicit rejection profile; filtered-out links do not trigger it. macOS directory-size queries may reject. |
| mktemp | Secure public randomness, exclusive creation and bounded collision retries establish ownership. No unsafe -u or inferred Windows ACL parity. |
| csplit names | Windows trailing dot/space names reject until verbatim creation, reading, enumeration and cleanup work. POSIX padding remains supported. |
| diff directories | Report FIFO/socket kinds without reading them. Distinct device numbers require public metadata. |
| unlink | Preflight exactly one operand before deletion; directory symlinks are removed as names. |

Mkdir's symbolic creation plan accounts for platform sticky-bit capability:
the selected Darwin +t result is 01777, Linux 01755. Do not add a compensating
setuid/setgid mask. Special-bit comparisons require the same process security
context and an observer permitted to change those bits. The earlier
restricted-versus-unrestricted Darwin comparison was invalid; the
[historical correction](https://github.com/moonbit-community/cmd/blob/c4ea7795b0eb6e6fd6d0dffa0e7709809569bbb1/docs/adr/0004-filesystem.md#mutation-and-identity-boundaries)
preserves its scope. Group-dependent setgid evidence remains platform-specific.

Tree's name-only link profile resolves issue #74 without fabricating readlink
text or replacing it with realpath. Dangling and cyclic links remain displayable.
Size requests reject selected links before querying their referents, and
`ln=target` color requests reject instead of following the target. Reopen target
display only with public readlink support. Async 0.22.7 already exposes no-follow
entry sizes; extending tree's selected-link-size profile is a separate decision
requiring exact link, dangling-target and no-follow tests. The CLI contracts in `tests/cases/tree.json`
and private traversal tests in `commands/tree/symlink_wbtest.mbt` own this scope.

## Metadata predicates and parent creation

Find and standalone test inspect file sizes through metadata, never by opening
the file or inventing a fallback size. Find uses no-follow entry size, UInt64
thresholds and upward unit rounding; test follows the validated target. Public
ENOTSUP produces an explicit error (find 1, test 2). macOS directory size remains
such a boundary. POSIX trailing separators require a directory before physical
resolution, including the macOS Wasm file-link case.

Find retains the stat fields needed by its expression before directory reads,
actions or child processing, while each evaluated empty-directory query reads
names again. An observed enumeration error remains a final failure even if a
later action deletes the directory or resets its listing cache. Actions obey
short circuits and expression order. Postorder cannot
reclassify a parent as newer merely because deleting its child changed mtime.
Prune/delete combinations require explicit depth. The default GNU optimization
profile promotes name/path/constants within its left operator chain, preserving
right compound groups and action barriers. These are command-private rules.

Age and used predicates follow the fixed GNU 4.10.0 window definitions and
finite binary64 input grammar, with signed 64-bit second bounds. Nonfinite and
out-of-range C conversions are not a portable contract. The current public
startup clock is millisecond-based; file timestamp nanoseconds are retained.
The a/c/m reference matrix uses distinct fields and ordered real ctimes, and
persists raw observations outside successful fixture cleanup. A local contract
or numerical vector does not substitute for immutable Linux differential runs.
Create its files in the reverse order from later metadata changes, so birth time
cannot masquerade as status-change time. Windows records CreationTime separately
as a negative control, queries real NTFS file IDs/hard-link lists and retains
attributes/ACLs without calling them POSIX permission bits. Missing required
host setup or observation fails infrastructure; host utilities never implement
the product predicates.

The async 0.22.7 Native Windows observer returns FILETIME seconds since 1601;
its records retain that raw pair and subtract 11,644,473,600 seconds only in the
test observer. The pinned Wasm host already converts to Unix time in
[`windows_timestamp`](https://github.com/moonbitlang/moon/blob/940aa18df6db921386e87e16fa94b84fa267864b/crates/moonrun/src/filesystem/job/stat.rs#L246).
Do not apply the correction to product code. Fixed .NET UTC setup/readback and
the actual current clock validate the conversion, while 24 Windows Wasm age
controls distinguish old, future and fresh timestamps; relative comparisons
alone cannot detect a shared epoch error. A changed Native API epoch must fail
the fixed preconditions until the observer is reviewed.

The stateful contracts in `tests/scenarios/filesystem_{predicates,special,time,
precision,windows,unreadable}.mbt` retain original modes, identities, timestamps and effects.
Sparse fixtures above 2 GiB retain allocation and sentinel receipts outside the
large payloads. POSIX socket, character and block nodes have actual positive and
mutually exclusive negative controls; the socket is an inode left after its
owned setup process has stopped, not a live-listener claim. These node fixtures
do not apply to Windows. Windows executes ordinary-file negatives and its own
file-link, directory-link and junction controls. The Linux immutable oracle is
an additional execution gate; generated definitions do not establish acceptance.
Unreadable size fixtures require real mode 000 and failed read-open, exercise
empty/full positive and negative controls, and compare original metadata before
observer-only permission restoration and exact retained-content checks. Protected
restoration also runs on failure so owned fixtures cannot block artifact upload.
The error-order fixture pins the denied link's atime in 2099 and verifies it
after observer readlink/follow before taking the baseline. This stabilizes
relatime observations; it does not claim that link access preserves atime on
every mount. Exact GNU diagnostic expectations retain the invoked
`/oracle/bin/find:` prefix without stripping actual error output. The first
[PR validation failure](https://github.com/moonbit-community/cmd/actions/runs/42437838515)
is retained and is not acceptance evidence.

Same-second precision fixtures admit only actual equal seconds and strictly
ordered nanoseconds in range. Wall-clock start estimates cannot establish that
condition: the first [actual-main run](https://github.com/moonbit-community/cmd/actions/runs/42441153813)
observed writes across a second and failed before invoking either product or
oracle. Preparation now records at most eight real timestamp pairs within a
10-second total deadline; only a pair failing the metadata condition may cause
another preparation. I/O, observation-write and cancellation failures propagate.
Exhaustion remains infrastructure failure. The six test and two find calls run
once after admission, followed by the original metadata/content preservation
checks. Private injected regressions check preparation control flow only; actual
CLI evidence always comes from real filesystem writes and timestamp readback.

Standalone test applies its one-through-four-argument rules before recursive
parsing. Its missing-operand time comparisons intentionally differ from the
shared shell's subset. Integer comparisons accept signed 64-bit decimal with
an optional sign and surrounding ASCII whitespace; radix prefixes, separators
and internal whitespace reject. GNU's unbounded integer range remains outside
this profile. Unary `-a` and find's uppercase size `K` remain named
project extensions. Public access checks are not raw permission observations
and do not establish differing real/effective-identity or ACL parity.

Mkdir checks public write/search access after creating each new POSIX parent.
A failed check reports capability status 2 and retains already-created parents;
later operands are attempted. It cannot safely reproduce GNU's owner-bit
adjustment without raw mode/umask, and does not guess a chmod mask. Access may
succeed under elevated privileges or ACLs even when the raw owner bits differ;
success therefore does not establish complete GNU parent-mode parity. Windows
explicit numeric and symbolic modes reject before creation, while all-existing
`-p` operands remain no-ops. Reopen the permission boundary with public mode or
umask operations and independent parent/leaf, ACL and privilege observations.

## Verification and reconsideration

Use relational link/metadata assertions, fixed timestamps and observations
before reads that can change atime. Missing required observers fail. Keep
positive operations, conservative rejections and partial effects distinct.

Reopen a boundary only with its public capability or a sound algorithm and
applicable Wasm-host, alias, mode, error-order and pinned-oracle tests.
[Compatibility](../compatibility.md) owns command support details.
Implementation and regressions: [fsops](../../core/fsops/),
[filesystem scenarios](../../tests/scenarios/scenario_filesystem.mbt).
