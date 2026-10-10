# ADR-0009: Honest Failure and Upstream Side Effects

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-10
Revision: Preserve gzip trailer-error output and distinguish exact patch preflight boundaries from GNU partial-hunk application.

## Target and decision

Unsupported structures fail before their execution or unsafe mutation. Supported commands retain upstream operand order, partial output/writes and earlier successful operands after later failure. Nonzero status is not global rollback. Cp rejects unsafe overwrite; touch does not rewrite bytes; expansion errors cannot become successful empty output.

## Alternatives and compatibility cost

The first patch release uses exact-hunk preflight for supported output/dry-run
and creation/deletion requests. Mismatched hunks fail before writing the
affected file and are boundary cases, not evidence for GNU partial-success or
reject-file semantics. Offset search, fuzz and `.rej` generation are project
work; reopening requires mixed-success multi-hunk/multi-file oracle tests.
This exception does not authorize transactional behavior for other commands.

gzip emits decoded prefix bytes before CRC/size/truncation failure. Replacing
the public Decoder with a pure MoonBit inflater avoids silently losing bytes
generated in a read that later throws. Native/Wasm fixtures cover this boundary;
the fixed GNU 1.14 roundtrip/error probe records the independent oracle evidence.

Reject universal preflight/transaction semantics and the release runner's unconditional nonzero-means-unchanged-fixture rule. Differential runs compare final effects with the oracle even on failure. Retain operation-specific preflight where APIs cannot prevent known data loss, documented in ADR-0004.

## Versions and evidence

Baseline: async 0.22.4, x 0.5.5, moonjq 0.1.2; MoonBit 2026-09-20.
The original audit's hard-link corruption and arithmetic false success are regression triggers. Filesystem preservation, expansion tests and release byte/snapshot comparison protect the separate contracts.
Historical results remain in [the audit](../reports/2026-09-19-command-fidelity-audit.md).
Candidate runtime results are recorded separately from published versions.

## Revisit when

Document actual partial-effect rules for newly supported operations. Reopen rejected operations when public APIs can implement them correctly; record alternatives, cost and measured evidence.
