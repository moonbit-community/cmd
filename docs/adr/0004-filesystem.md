# ADR-0004: Maximum Strict Filesystem Subset

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-20

The pinned GNU coreutils 9.11 Linux run also establishes status 1 when an
interactive ln/mv overwrite is declined, including EOF. Preserve both paths,
continue other operands, and aggregate the failure. A no-clobber/update skip
remains a distinct successful no-op. Earlier golden status 0 was wrong;
real Native/Wasm and published regressions retain the corrected upstream status.
Revision: Integrate the async 0.22.5 Native Windows link-rename fix in the accepted stage 0 subset, retain a separate Wasm host gate, and preserve the existing identity and metadata boundaries.

## Stage 0: Windows link rename

Stage 0 publishes `cli/mv@0.2.3` with core 0.7.0 and async 0.22.5.
The [release report](../reports/2026-10-20-stage0-release/README.md) records independent Windows
Native/Wasm execution, exact published-host rejection and runtime identities.
The upstream
[Native implementation](https://github.com/moonbitlang/async/blob/11749dec32e2b4de8cc8a6101e18110019c29893/src/internal/event_loop/fs.c#L1504)
adds `FILE_FLAG_OPEN_REPARSE_POINT` when opening the source of a Windows rename,
so the operation addresses a symbolic link or junction itself. The
[Wasm implementation](https://github.com/moonbitlang/async/blob/11749dec32e2b4de8cc8a6101e18110019c29893/src/internal/event_loop/thread_pool.wasm.mbt#L434)
imports the rename job from the host. Updating the package does not update or
identify that host implementation.

The published `mv` therefore rejects Windows Wasm source symlink/junction moves
and destination-link backups before prompting or changing paths. No-clobber
and update-none skips remain available. `-u` timestamp-based link skips are not
claimed: the Wasm guard runs before timestamp lookup. Native uses the released fix; neither
that source inspection nor a macOS run proves Windows behavior. Explicit
`symbolic-link` fixtures use `force_symlink=true`, while Windows `junction`
fixtures use an existing directory and `force_symlink=false`. A fixed host
observer checks the Windows link type and target; tests also assert source,
destination, backup and referent contents. Missing privileges or observations
are infrastructure failures, not successful or skipped semantic evidence.

Interactive rejection scenarios hold stdin open without writing and require
exit within the observer deadline, no overwrite prompt and an unchanged complete
fixture. Separate rounds retain the currently allowed regular-source replacement
of a destination link without backup on both backends; Windows execution must
establish its actual effects. Native package fault injection observes a completed
link/junction backup before failing the commit, then checks restoration of the
link type, target and referent bytes. The corresponding Wasm test must reject
before the injection point. Actual Windows runs cover these assertions;
package fault injection does not establish a real CLI post-backup filesystem
failure or recovery.

Overwrite/update timestamp decisions now read the source and destination
entries with `follow_symlink=false`. A dangling source link remains movable;
the timestamp lookup must not fail merely because its referent is absent.
This uses the released public timestamp API and does not provide file identity.
Equal-time identity-dependent decisions retain their existing rejection.

Unlock the Wasm boundary only after identifying a released host containing the
fix and passing independent Windows Native/Wasm tests for file symlinks,
directory symlinks, junctions, backup paths and unchanged referents. The tests
and their current rejection evidence do not establish a fixed Wasm host.
Track that host-specific evidence in [issue #38](https://github.com/moonbit-community/cmd/issues/38),
a child of the broader [filesystem issue #10](https://github.com/moonbit-community/cmd/issues/10).
The published baseline remains the coordinates in the
[support record](../compatibility.md). The other 75 command coordinates
remain unchanged by this partial publication.

The 0.22.5 public fs interface adds no identity, mode reader, handle truncate,
timestamp setter, hard-link or readlink API. The metadata and inode boundaries
below still apply. References to 0.22.4 in the retained decisions describe
their original verification baseline, not a new acceptance result.

## Target and decision

The retained ls link/time corrections must also be released as `cli/ls@0.2.1`:
the old 0.2.0 coordinate fails the new time-order contracts. Follow command-line
links with `-H`, all selected links with `-L`, and preserve the documented `-P`
extension. `-u/-c/--time` imply time ordering unless an explicit `-S/-t` selects
sorting; retain GNU 9.11 tie, dangling-link and precedence contracts. Reject
metadata-dependent long listings and unsupported directory-size sorting instead
of inventing values. Public mode/owner/link APIs plus differential fixtures are
the conditions for expanding that subset. Passing local source tests never
substitutes for rerunning the exact published coordinate.

The 2026-10-11 second review (issue #25, coreutils 9.11) requires the last ln
`-f/-i` selector to win. For mv, canonical parent paths identify the same entry
before prompting/backups; ordinary rename must remove the source entry. A
hard-link no-op therefore fails with both names intact. Never delete the source
again to force the postcondition: a concurrent actor may have recreated it.

Public async 0.22.4 has no file identity read before the operation. An equal-mtime
target with interactive or older-only update selection cannot be distinguished
from a hard-link alias before a prompt/skip. Refuse that ambiguous case explicitly,
including separate files with matching times; no-clobber/update-none remain valid
skips. Timestamp equality is not treated as proof of identity. Rejected alternatives
are success on an unverified alias, guessing identity from content/time, private
runtime access and host mv delegation. The compatibility cost is conservative
refusal for that equal-time subset and a reported error if concurrent source
recreation defeats the rename postcondition. Public identity/handle metadata plus
Native/Wasm hard-link, symlink, backup, interaction and race tests can lift the
restriction. JSON regressions retain source bytes, mode, link relations and backup
absence; Linux fixed GNU is the independent oracle, Windows contracts are separate.

Implement each backend's maximum correct subset. Public async 0.22.4 lacks identity, mode reads and handle truncation. Default cp therefore fails instead of creating wrong permissions. GNU --no-preserve=mode supports new destinations with 0666/0777 subject to umask; existing regular-file overwrite is rejected. No-clobber/update no-ops remain. Touch creates missing files and implements -c for missing operands; existing timestamp updates fail without content writes. Numeric chmod follows command-line symlinks and skips recursively encountered symlinks. mkdir -p -m applies the requested mode only to the leaf. Exotic umasks requiring temporary owner permissions remain uncertified.

The current async 0.22.4 baseline makes existing-target canonicalization
available through public `fs.realpath`; `realpath` therefore implements existing
paths, `-e` and `-z` while rejecting missing-path GNU extensions. `tree` uses
public directory traversal and rejects symbolic links before output because
readlink is still unavailable. `mktemp` uses public `env.rand` plus exclusive
CreateNew/mkdir retries; it never uses timestamps or rename as a safety claim.

Tests request metadata dimensions explicitly. Shared snapshots collect metadata
before content, use host `stat`/`readlink` only as test observers on POSIX, and
compare hard-link equivalence within each fixture rather than raw inode values
across independent directories. Timestamp assertions use fixed values or
before/after relationships. Required missing observers produce infrastructure
failure; platform-inapplicable cases are explicit skips. Neither is a semantic
pass. This observation capability does not expand product command APIs.

## Alternatives and compatibility cost

The new patch profile applies exact unified/context hunks to stdout or in a
dry run, and supports unambiguous creation/deletion. Existing-file replacement
and named `-o` output refuse because GNU patch preserves source mode. Unlike cp,
patch may replace the target inode: rename itself is available. Reject direct
truncate/write because it mutates hard-link aliases, and reject default-mode
temporary replacement because it loses source permissions. The compatibility
cost is that ordinary `patch < change.diff` cannot update an existing file yet.
Evidence: [2026-10-10 inode/mode observation](../reports/2026-10-10-patch-file-semantics.md),
async 0.22.4 public fs interface and exact-hunk contract cases. Reopen ordinary
writeback after public mode metadata and fixed GNU mode/link regressions pass.

split/csplit use exclusive creation for new outputs and refuse collisions.
They do not emulate existing-target truncation with rename or infer identity
from spelling. This limits repeated splitting into existing names; public
handle identity/truncation and same-file alias tests are the unlock condition.
Ordinary partial output/cleanup behavior remains separately tested.

Reject realpath as inode identity, temporary rename as inode-preserving overwrite, content rewrites as touch, internal imports and own FFI. This intentionally contracts the old false-success surface. POSIX EXDEV is now classifiable via async.platform, but correct mv fallback still requires mode/link/timestamp preservation.

The 2026-09-21 public API recheck found a possible Linux Native procfs route,
not a portable fd API. Unix Native exposes OS fd, Windows exposes HANDLE and
Wasm an opaque host handle. Keep this route experimental until fdinfo/mountinfo
identity, bind mounts, path replacement, permission changes and missing procfs
are tested together. It does not recover source mode. The compatibility cost
remains refusal of existing-file copies; no content/lock/access heuristic is
accepted as identity or metadata. See the [recheck](../reports/2026-09-21-public-api-recheck.md).

## Versions and evidence

Recheck: async 0.22.4, x 0.5.5, moonjq 0.1.2; moon 0.1.20260920,
moonc 0.10.14+7d59c7ec9. Original release evidence retains its earlier baseline.
The unified filesystem scenarios retain the former standalone fidelity probe's
same-file/hard-link source preservation, new-file copy, unchanged mtime/content
on touch rejection, parent/leaf permissions and chmod symlink assertions. Their
reports identify the tested backend and observed dimensions. Linux pinned
oracle validation remains a separate gate from local macOS results. The
support record distinguishes public from internal capabilities.
Historical results remain in [the audit](../reports/2026-09-19-command-fidelity-audit.md).
Candidate runtime results are recorded separately from published versions.

## Migrated filesystem profiles

Target: preserve upstream path effects and fail without destructive guesses.
Version evidence is async 0.22.4 on MoonBit 2026-09-20, the public fs interface,
per-command `tests/cases/<command>.json` and the 0.1.1/0.1.0 release reports.
Every row retains the pure MoonBit boundary; host observers never implement it.

| Commands | Choice and reason | Rejected alternative / compatibility cost | Evidence and unlock condition |
| --- | --- | --- | --- |
| realpath | Reuse public realpath for existing paths; `-e/-z` and ordered operands are supported. | Do not lexically remove components and call it symlink-aware canonicalization. Missing-last/default behavior, `-m`, relative output and `-s` need separate work; lexical `-s` is implementable, full missing-path link resolution may need readlink. | `realpath.json`, 0.1.1 release. Add missing intermediate/final components, broken links, `..` after links and relative-base cases before expanding. |
| tree | Deterministic ordinary-directory traversal with depth/hidden/type selection and totals; preflight unsupported links. | Do not silently omit symlinks or use realpath as original link text. This restricts even default tree on common linked directories. JSON/HTML/filters/colors are project work; link arrows/loops and owner/mode/device output need specific APIs. | `tree.json`, first-batch report and public readlink/identity absence. Add exact link text, dangling/loop fixtures and metadata observers when APIs appear; algorithm-only output modes need no upstream wait. |
| mktemp | Public randomness plus exclusive creation, collision retries and 0600/0700 creation permissions; use one trailing-X template. | Reject predictable time names and exists-then-create races. `-p`, suffix/template variants and quiet mode are deferred parsing work; owner/Windows mode parity is unverified. | `mktemp.json` and first-batch report. Expand with deterministic collision injection, template/env precedence, umask and per-platform permission observations. |
| unlink | Preflight exactly one operand, then remove a non-directory name without following symlinks. | Reject the previous multiple-removal extension: extra operands return 1 before any unlink. This intentionally removes non-GNU behavior; no ownership API is required. | Coreutils 9.11 plus two untouched files, single file, -- dash-name and directory-target symlink regressions. No pending API gate for ordinary unlink; widen only to upstream behavior with side-effect evidence. |
| split, csplit | Exclusive new pieces; buffered input, byte/line or regex boundaries and deterministic suffixes. csplit cleans only files this invocation created unless `-k` requests retention. | Do not truncate collisions or remove pre-existing files during cleanup. Input-sized memory, split Int32 counts and suffix bounds are costs; chunk/filter/custom-suffix modes are implementation work. | Their JSON/package tests, collision/cleanup fixtures. Add streaming/counter and suffix-exhaustion tests for algorithm expansion; existing-name overwrite still requires the handle identity/truncation gate above. |
| patch | Exact-hunk stdout/dry-run and explicit create/delete are usable now; existing pathname or named-output replacement remains unavailable. | Rename can replace inode, but not preserve unknown source mode. Reject both unguarded in-place writes and wrong-mode replacement; fuzz/offset/reject files are separate algorithm work. | Mode/link observation and contracts cited above. Public mode + safe replacement and GNU hard-link/mode/mixed-failure fixtures unlock writeback; hunk algorithms follow ADR-0009. |

## Revisit when

Reopen when released public handle identity/mode, truncate, time setters and link APIs support the required semantics. Validate Native/Wasm independently; missing public identity does not mean Wasm hosts have no inode capability.
