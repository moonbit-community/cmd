# ADR-0009: Honest Failure and Partial Effects

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-30

## Decision

Unsupported operations fail before execution or unsafe mutation. Supported
operations preserve operand order, partial output/writes and earlier successful
operands after later failure. A nonzero status does not imply global rollback.
Expected rejection must assert its diagnostic and required unchanged state;
it is not support for that operation.

## Operation-specific effects

| Operation | Required behavior |
| --- | --- |
| patch | A failed hunk preserves its input region and permits later hunks. Own new reject handles; dry-run creates no target/reject files. Existing-path limitations remain in ADR-0004. |
| gzip decoding | Preserve output before CRC, size, framing, truncation or reader failures. Cleanup never retries a failed write. |
| cp/touch/mv | Refuse unsafe preservation/overwrite; never rewrite content to simulate timestamps. EXDEV fails without a metadata-losing fallback. Never delete a recreated/remaining source to force rename success. |
| split/csplit | Own exclusively created outputs. Split retains completed pieces after later failure; csplit removes owned fragments unless -k. Never remove pre-existing names. |
| curl/wget | Follow separate retry, opening, prefix and cleanup profiles. A failed writer may have made an unmeasurable partial write; network failure does not mean an untouched file. |
| unlink/parsers | Extra unlink operands reject before deletion. Accepted syntax is not implemented semantics; unsupported shell constructs must not become empty successful output. |

## Consequences and verification

Reject universal transactional preflight, unconditional rollback and the test
assumption that every failure leaves fixtures unchanged. Compare partial
effects with the pinned oracle; retain narrow preflight where public APIs
cannot avoid a known unsafe effect. Historical defects are not design freedoms
and must not be preserved by weakening tests.

Lift a boundary only with a public API or sound algorithm, positive and failure
cases, aliases and partial-output assertions on applicable Wasm hosts. Delivery,
publication and performance remain separate gates under
[ADR-0001](0001-evidence.md).

Executable evidence: [testkit](../../tests/testkit/),
[filesystem scenarios](../../tests/runner/scenario_filesystem.mbt),
[patch cases](../../tests/cases/patch.json) and package error regressions.
