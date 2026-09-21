# ADR-0004: Maximum Strict Filesystem Subset

Status: Accepted
Date: 2026-09-05
Updated: 2026-09-21
Revision: Keep strict filesystem boundaries and make test metadata observations explicit.

## Target and decision

Implement each backend's maximum correct subset. Public async 0.22.1 lacks identity, mode reads and handle truncation. Default cp therefore fails instead of creating wrong permissions. GNU --no-preserve=mode supports new destinations with 0666/0777 subject to umask; existing regular-file overwrite is rejected. No-clobber/update no-ops remain. Touch creates missing files and implements -c for missing operands; existing timestamp updates fail without content writes. Numeric chmod follows command-line symlinks and skips recursively encountered symlinks. mkdir -p -m applies the requested mode only to the leaf. Exotic umasks requiring temporary owner permissions remain uncertified.

Tests request metadata dimensions explicitly. Shared snapshots collect metadata
before content, use host `stat`/`readlink` only as test observers on POSIX, and
compare hard-link equivalence within each fixture rather than raw inode values
across independent directories. Timestamp assertions use fixed values or
before/after relationships. Required missing observers produce infrastructure
failure; platform-inapplicable cases are explicit skips. Neither is a semantic
pass. This observation capability does not expand product command APIs.

## Alternatives and compatibility cost

Reject realpath as inode identity, temporary rename as inode-preserving overwrite, content rewrites as touch, internal imports and own FFI. This intentionally contracts the old false-success surface. POSIX EXDEV is now classifiable via async.platform, but correct mv fallback still requires mode/link/timestamp preservation.

## Versions and evidence

Baseline: async 0.22.1, x 0.5.5, moonjq 0.1.2; MoonBit 2026-09-15.
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
