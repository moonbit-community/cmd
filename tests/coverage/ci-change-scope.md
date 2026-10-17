# Reviewed current-version CI impact

Base: `03cc8a5c9283e859e55bd2ae3faf2dd1b0e4df05`.

This harness-only change repairs published boundary-report observations. The
executor already checks rejection status, diagnostics and fixture preservation;
when a nonzero expected status is declared, it also checks the explicit stream
contracts. The serializer must record those executed assertions. Legacy
rejection fixtures with expected status zero must not claim stream assertions
that the executor did not perform. A boundary pass remains rejection evidence.

The existing registered serialization regression covers exact byte assertions,
stream contracts, legacy rejection handling, failed rows and the distinction
between boundary and semantic passes. Its Native evidence is required on Linux,
macOS and Windows.

The local push audit now accepts the same empty command scope for a genuine
harness-only range. The existing harness-only audit regression covers the
accepted local declaration and rejection of product or shared-runtime changes,
command-owned behaviors, unbound paths, mismatched reviewed impact and missing
evidence. This behavior also requires Native evidence on all three platforms.
Reviewed path bindings cover the serializer, audit validator and entry, impact
parser, documentation and this scope description; modified test sources
are owned by their declared behaviors.

The Windows HTTP lifecycle observer uses the system TCP listener table through
the existing PowerShell diagnostic boundary. It reports actual loopback
endpoints, with strict status, stderr and endpoint validation. The existing
observer regression rejects timeout and cleanup errors separately, including
apparently valid partial output. The real HTTP lifecycle regression retains its
active-listener control, response/body assertions and joined-cleanup absence
check. Its five-second fixture deadline and the observer's fifteen-second
deadline are unchanged. Both registered behaviors require Native evidence on
Linux, macOS and Windows; the canonical ADR records the observation boundary.

No command behavior, package version, frozen input or recorded report changes.
The CI declaration contains impact and requirements only. After merging, current
published regression and downloaded-report verification must establish the
observations from a fresh run at the actual main commit. Existing reports are
not rewritten to add missing observations.
