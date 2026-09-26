# ADR-0003: Preserve Streams and Caller Locale

Status: Accepted
Date: 2026-09-05
Updated: 2026-09-21
Revision: Move fixed locale into test environments and byte contracts into the shared catalog.

## Target and decision

Preserve byte streams, final newlines and partial output. Set LC_ALL=C explicitly in differential fixtures; inherit caller locale in real commands. C-byte collation tests do not certify non-C behavior. Keep bounded sort and descriptor-follow tail as declared subsets.

## Alternatives and compatibility cost

Reject universal newline normalization, whole-output trimming and forced locale. Command substitution removes trailing LF only, preserving spaces and embedded newlines. Grep separators require requested context; base64 -w0 emits no newline. Full locale-aware comparisons remain unverified.

## Versions and evidence

Baseline: async 0.22.4, x 0.5.5, moonjq 0.1.2; MoonBit 2026-09-20.
Exact CLI contracts in tests/cases cover grep, base64 and shell substitution on both backends. The original audit records the previous mismatches; the original fidelity probe is retained in the 2026-09-21 evidence archive.
Historical results remain in [the audit](../reports/2026-09-19-command-fidelity-audit.md).
Candidate runtime results are recorded separately from published versions.

## Revisit when

Add locale profiles only when implementation and oracle evidence cover them; never rewrite the caller environment to hide a gap.
