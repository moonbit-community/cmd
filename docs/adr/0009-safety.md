# ADR-0009: Honest Failure and Upstream Side Effects

Status: Accepted
Date: 2026-09-05
Updated: 2026-09-20
Revision: Replace universal transactional rejection with command-specific effects.

## Target and decision

Unsupported structures fail before their execution or unsafe mutation. Supported commands retain upstream operand order, partial output/writes and earlier successful operands after later failure. Nonzero status is not global rollback. Cp rejects unsafe overwrite; touch does not rewrite bytes; expansion errors cannot become successful empty output.

## Alternatives and compatibility cost

Reject universal preflight/transaction semantics and the release runner's unconditional nonzero-means-unchanged-fixture rule. Differential runs compare final effects with the oracle even on failure. Retain operation-specific preflight where APIs cannot prevent known data loss, documented in ADR-0004.

## Versions and evidence

Baseline: async 0.22.1, x 0.5.5, moonjq 0.1.2; MoonBit 2026-09-15.
The original audit's hard-link corruption and arithmetic false success are regression triggers. Filesystem preservation, expansion tests and release byte/snapshot comparison protect the separate contracts.
Historical results remain in [the audit](../reports/2026-09-19-command-fidelity-audit.md).
Candidate runtime results are recorded separately from published versions.

## Revisit when

Document actual partial-effect rules for newly supported operations. Reopen rejected operations when public APIs can implement them correctly; record alternatives, cost and measured evidence.
