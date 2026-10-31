# ADR-0002: Upper Layers Own Authorization

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-30

## Decision

The embedding application or runtime host owns authorization. Commands preserve
argv, cwd, streams, status and the complete inherited environment according to
their semantics. Only explicit operations such as env `-i/-u` or shell export
rules modify that environment. Catalog tiers and capabilities describe required
authority; they neither grant permissions nor filter execution.

Restricted commands include chmod, curl, env, find, make, rg, sh, split,
timeout, wget and xargs. Rg preprocessing and split filters may launch external
children even when ordinary invocations use only builtins. Sort and other
spooling commands declare temporary FileWrite requirements; a small read-only
invocation does not prove that a spill is authorized.

## Consequences and rejected alternatives

Do not add a second command-local permission engine or silently reduce an
authorized environment. Distinguish host denial, invalid parameters and missing
implementation. Process groups are lifecycle mechanisms, not authorization.

Root protection for rm follows its option-order semantics. Final `.` and `..`
operands remain rejected; a named working directory is not an extra permission
boundary. Tests exercise decision helpers and disposable fixtures, never root
deletion.

## Verification and reconsideration

The policy suite checks real child launch and temporary writes with permission
denied and explicitly allowed. Spill-denial fixtures selectively inherit
TMP/TEMP/TMPDIR so Windows can resolve a temporary path without granting writes.
Keep command semantics unchanged when adapting host permission interfaces;
only upstream rules justify command-local environment changes.

Implementation: [catalog](../../core/contracts/catalog.mbt),
[process context](../../core/process/process.mbt),
[policy scenarios](../../tests/runner/policy.mbt). Delivery gates are defined
once in [ADR-0001](0001-evidence.md).
