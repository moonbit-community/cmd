# ADR-0004: Maximum Strict Filesystem Subset

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-11
Revision: Complete realpath/tree/mktemp/unlink and splitting decisions; separate implementable path/format work from identity, metadata and link API gates.

## Target and decision

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
oracle validation remains a separate gate from local macOS results. See
../async-upstream-gaps.md for public versus internal capabilities.
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
| unlink | Directly remove non-directory operands without following symlinks; current multi-operand form preserves order and earlier removals. | Multiple operands are a project extension: GNU unlink accepts exactly one and rejects extra operands before mutation. Do not count multi-operand success as GNU compatibility. No ownership API is needed for the ordinary operation. | `unlink.json`, source parser and 0.1.1 profile. Decide compatibility by rejecting extras before removal (preferred command-fidelity direction), then add an untouched-two-files regression; no async blocker. |
| split, csplit | Exclusive new pieces; buffered input, byte/line or regex boundaries and deterministic suffixes. csplit cleans only files this invocation created unless `-k` requests retention. | Do not truncate collisions or remove pre-existing files during cleanup. Input-sized memory, split Int32 counts and suffix bounds are costs; chunk/filter/custom-suffix modes are implementation work. | Their JSON/package tests, collision/cleanup fixtures. Add streaming/counter and suffix-exhaustion tests for algorithm expansion; existing-name overwrite still requires the handle identity/truncation gate above. |
| patch | Exact-hunk stdout/dry-run and explicit create/delete are usable now; existing pathname or named-output replacement remains unavailable. | Rename can replace inode, but not preserve unknown source mode. Reject both unguarded in-place writes and wrong-mode replacement; fuzz/offset/reject files are separate algorithm work. | Mode/link observation and contracts cited above. Public mode + safe replacement and GNU hard-link/mode/mixed-failure fixtures unlock writeback; hunk algorithms follow ADR-0009. |

## Revisit when

Reopen when released public handle identity/mode, truncate, time setters and link APIs support the required semantics. Validate Native/Wasm independently; missing public identity does not mean Wasm hosts have no inode capability.
