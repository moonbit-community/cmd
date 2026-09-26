# ADR-0004: Maximum Strict Filesystem Subset

Status: Accepted
Date: 2026-09-05
Updated: 2026-09-26
Revision: Recheck public fd and procfs alternatives; add pure-MoonBit realpath, tree and mktemp subsets under async 0.22.4 while preserving strict metadata boundaries.

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

## Revisit when

Reopen when released public handle identity/mode, truncate, time setters and link APIs support the required semantics. Validate Native/Wasm independently; missing public identity does not mean Wasm hosts have no inode capability.
