# ADR-0002: Upper Layers Own Authorization

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-25
Revision: Classify split filter process authority while retaining host-owned authorization.

## Target and decision

Commands preserve argv, inherited environment, cwd, streams and status according to upstream semantics. The embedding application/runtime host owns authorization. Explicit env -i/-u and shell export rules still modify the environment as requested. Catalog tiers/capabilities describe requirements, never authorize or filter execution.

The current 79-command catalog has 69 Core/Extended commands and ten Restricted
commands: chmod, curl, env, find, make, sh, split, timeout, wget and xargs.
Split's `--filter` uses the pure MoonBit shell and can launch external children,
so its existing ProcessSpawn capability also requires the Restricted tier and
a policy-sensitive release profile. Builtins alone do not prove process
authorization. The policy-host cohort exercises an actual controlled external
filter child with process permission denied and explicitly allowed; it grants
no unrelated process or filesystem authority.

The unpublished sort candidate may create temporary runs after its in-memory
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

Baseline: async 0.22.4, x 0.5.5, moonjq 0.1.2; MoonBit 2026-09-20.
core/process/default_environment returns the complete environment on both backends. The `process-lifecycle` CLI scenario checks an unrelated variable and both C/POSIX LC_ALL values through a pure MoonBit child. The original published audit retains the old filtered results; its follow-up fidelity probe is archived with the 2026-09-21 evidence.
Historical results remain in [the audit](../reports/2026-09-19-command-fidelity-audit.md).
Candidate runtime results are recorded separately from published versions.

## Revisit when

Only upstream command rules justify local environment changes. Adapt changing host authorization interfaces without changing command semantics.
