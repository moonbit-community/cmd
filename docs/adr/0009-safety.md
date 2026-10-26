# ADR-0009: Honest Failure and Upstream Side Effects

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-26
Revision: Record current partial-hunk, stream-prefix and filesystem boundaries after the fidelity, D and R releases.

## Decision

Unsupported structures fail before their execution or unsafe mutation.
Supported operations retain operand order, partial output/writes and earlier
successful operands after a later failure. A nonzero status does not imply
global rollback. Expected rejection must assert the actual diagnostic and
required untouched state; it is not support for the rejected operation.

Current validation follows [ADR-0001](0001-evidence.md): applicable Wasm-host
tests, exact-version MoonX acceptance and the pinned Linux oracle. Native
product pairing and change-coverage audits are retired. Historical passes
keep their original versions, platforms and limitations.

## Current operation-specific effects

| Operation | Decision and cost |
| --- | --- |
| patch | Offset/fuzz matching and mixed hunk results are implemented. A failed hunk retains its input region while later hunks continue. New rejects use exclusive handles owned by this invocation; dry-run creates neither targets nor rejects. Existing-file/named-output mode preservation and replacement of existing rejects still refuse under ADR-0004. The original exact-hunk-only profile is superseded. |
| gzip/gunzip/zcat | Decoding preserves bytes produced before CRC, size, framing or truncation failure. Reader errors and failed writes retain their distinct effects; cleanup never replays a failed write. A decoder that loses its already-produced prefix is not an equivalent replacement. |
| cp, touch, mv | Cp refuses unsafe preservation/overwrite; touch never rewrites content to simulate timestamps. Mv performs rename; EXDEV is failure, with no copy/delete fallback. A source that remains after a rename no-op must not be deleted to manufacture success. |
| split/csplit | New outputs are exclusively owned. Split retains completed pieces after later failure; csplit removes owned fragments unless -k requests retention. Cleanup must never remove pre-existing names. |
| curl/wget | Retry, lazy output opening, prefix preservation and cleanup follow separate command profiles in ADR-0005. Network failure does not imply an untouched file, and a failed Writer call has uncertain partial-write extent. |
| unlink and parsing | Extra unlink operands reject before any deletion. Unsupported shell expansion or grammar must not become successful empty output. Parser acceptance alone does not establish semantic support. |

## Alternatives and compatibility cost

Reject universal transactional preflight, unconditional rollback, and the
old runner assumption that any nonzero result leaves fixtures unchanged.
Compare supported partial effects with the upstream oracle. Keep narrow
preflight only where current public APIs cannot avoid a known unsafe effect.

The 2026-10-11 strings/column/which/date findings were defects, not design
permissions. Subsequent fixes changed flags, access checks, layout and timezone
handling and were published. Their historical failures remain in Git; current
regressions must not be weakened to preserve the old wrong behavior.

## Source and history

- `6fff343` and `c1ff8a2`: fidelity corrections, conservative filesystem
  boundaries and repair/publication history.
- `73503a3`: offset/fuzz and mixed-result patch implementation, retained in
  [apply.mbt](../../commands/patch/apply.mbt) and
  [main.mbt](../../commands/patch/main.mbt); cases in
  [patch.json](../../tests/cases/patch.json).
- `3c50c94` and `1ffa967`: streaming gzip and prefix/error behavior, retained
  in [gzipops](../../core/gzipops/) and its Reader/error regressions.
- [testkit](../../tests/testkit/) and [filesystem scenarios](../../tests/runner/scenario_filesystem.mbt)
  compare status, bytes and final effects independently. Dated releases are
  summarized in [CHANGELOG.md](../../CHANGELOG.md).

## Revisit when

Lift a rejection only when public APIs or a sound project algorithm implement
the required effects, with positive, failure, alias and partial-output tests
on applicable Wasm hosts and the fixed oracle. Keep publication and formal
resource/performance acceptance separate from passing focused tests.
