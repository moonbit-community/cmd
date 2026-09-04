# Architecture Decision Records

These records describe the decisions that shape the observable command
surface. They follow the MoonJust ADR convention: each record has a status,
context, decision, consequences, evidence, and rollback. Evidence is a
black-box Wasm run; source inspection and unit-test results are not treated as
capability evidence.

| ADR | Decision |
| --- | --- |
| [0001](0001-black-box-support-record.md) | Use real Wasm artifacts as the support authority |
| [0002](0002-stdin-and-terminal-behavior.md) | Keep implicit stdin byte-clean and silent |
| [0003](0003-portable-chmod-profile.md) | Numeric permission mutation only |
| [0004](0004-portable-copy-profile.md) | Copy data, do not invent metadata preservation |
| [0005](0005-http-client-profile.md) | Keep curl/wget HTTP behavior inside pure MoonBit |
| [0006](0006-environment-and-child-policy.md) | Make child execution explicit at the Wasm boundary |
| [0007](0007-find-expression-profile.md) | Implement a bounded find expression/action profile |
| [0008](0008-jq-filter-profile.md) | Publish the observed jq filter slice without overclaiming jq |
| [0009](0009-jqlog-imported-contract.md) | Measure jqlog against its imported contract |
| [0010](0010-symbolic-link-only-profile.md) | Support symlinks; fail closed for hard links |
| [0011](0011-portable-listing-profile.md) | Use deterministic portable ls output |
| [0012](0012-make-language-profile.md) | Execute a bounded Make language through MoonBit |
| [0013](0013-rename-without-cross-device-fallback.md) | Preserve source when rename cannot be classified |
| [0014](0014-safe-removal-profile.md) | Keep root/current-directory removal protection |
| [0015](0015-moonbit-shell-profile.md) | Interpret shell syntax without delegating a script |
| [0016](0016-sort-memory-profile.md) | Keep the Wasm sort implementation bounded and in-process |
| [0017](0017-tail-non-follow-profile.md) | Use portable descriptor-follow polling for tail |
| [0018](0018-timeout-publication-gate.md) | Keep timeout local-only behind process-group cancellation |
| [0019](0019-touch-timestamp-boundary.md) | Create/update files; reject arbitrary timestamp setters |
| [0020](0020-byte-oriented-tr-profile.md) | Use a byte-oriented tr profile |
| [0021](0021-wget-transfer-profile.md) | Support HTTP transfer controls, not recursive mirroring |
| [0022](0022-xargs-child-policy.md) | Keep xargs direct-child execution policy-visible |
| [0023](0023-xxd-seek-profile.md) | Verify forward hex and positive seeks only |
| [0024](0024-policy-is-part-of-behavior.md) | Record Wasm authorization separately from command semantics |
| [0025](0025-c-locale-record-profile.md) | Keep text-pipeline records deterministic under `LC_ALL=C` |
| [0026](0026-find-xargs-p4-workflow.md) | Bound metadata traversal and direct-child batching to portable Wasm capabilities |

The remaining commands have no additional portability trade-off beyond the
common evidence and stdin decisions. Their exact observed option surface is
listed in [`docs/compatibility.md`](../compatibility.md).
