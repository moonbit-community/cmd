# ADR-0002: Upper Layers Own Authorization

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-26
Revision: Classify split filter process authority while retaining host-owned authorization.

Delivery validation update (2026-10-26): [ADR-0001](0001-evidence.md) and the
[Wasm CI migration](../ci-wasm-migration.md) define current acceptance. Future
regressions and boundary unlock conditions below require Wasm on applicable
hosts and exact-version MoonX acceptance; Native command runs and backend
pairing are retired. Dated Native observations retain their historical scope.

## Target and decision

Commands preserve argv, inherited environment, cwd, streams and status according to upstream semantics. The embedding application/runtime host owns authorization. Explicit env -i/-u and shell export rules still modify the environment as requested. Catalog tiers/capabilities describe requirements, never authorize or filter execution.

The current 80-command catalog has 69 Core/Extended commands and eleven
Restricted commands: chmod, curl, env, find, make, rg, sh, split, timeout, wget
and xargs. Rg is an unpublished candidate; its --pre option can spawn a
user-selected process.
Split's `--filter` uses the pure MoonBit shell and can launch external children,
so its existing ProcessSpawn capability also requires the Restricted tier and
a policy-sensitive release profile. Builtins alone do not prove process
authorization. The policy-host cohort exercises an actual controlled external
filter child with process permission denied and explicitly allowed; it grants
no unrelated process or filesystem authority.

Published sort 0.2.3 may create temporary runs after its in-memory
budget fills. Its catalog includes FileWrite and the release profile marks it
policy-sensitive. The host still decides authorization: small input and check
mode can run without temporary writes, while denied spill creation fails before
sorted output. The existing host-policy scenario observes both small read-only
sorting and a real default-budget spill denied by the read-only policy.
The spill-denial fixture selectively inherits TMP/TEMP/TMPDIR so Windows can
resolve its temporary path before the write check. Filesystem writes remain
denied; the command does not add or filter the caller's environment.

## Alternatives and compatibility cost

Reject a second command-local policy engine and silently reducing an already authorized environment. Existing callers that relied on filtering must enforce that policy above the command. Distinguish host denial, missing implementation and invalid parameters.

## Versions and evidence

`rm --no-preserve-root` is no longer disabled by repository policy. Root
preservation follows upstream option order, while final `.` / `..` operands
remain rejected by command semantics. An explicit named working directory is
not an additional authorization boundary. Tests exercise the decision helper
and disposable fixtures only; no root deletion is executed.

Current dependencies are declared in `core/moon.mod` (async 0.22.5,
x 0.5.5 and moonjq 0.2.0). `core/process/default_environment` returns the
complete host environment; env/export semantics modify it only when requested.
The policy suite checks actual allowed/denied children and temporary writes.
Historical filtering was removed by the 0.2.0 fidelity work, not retained as
a current safety feature. Published coordinates remain independent of the
catalog-only core 0.8.2 workspace candidate.

## Revisit when

Only upstream command rules justify local environment changes. Adapt changing host authorization interfaces without changing command semantics.

## Source review (2026-10-26)

The complete-environment correction begins at `6fff343`; split authority changed in `db9dfe7`, and rg joined the catalog in `c048555`. Current sources are [catalog.mbt](../../core/contracts/catalog.mbt), [process.mbt](../../core/process/process.mbt) and the [policy suite](../../tests/runner/policy.mbt). Catalog tiers never grant permissions.
