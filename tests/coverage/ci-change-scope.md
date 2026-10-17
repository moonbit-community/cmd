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
macOS and Windows. The reviewed path bindings cover the serializer and this
scope description; the modified test source is owned by the declared behavior.

No command behavior, package version, frozen input or recorded report changes.
The CI declaration contains impact and requirements only. After merging, current
published regression and downloaded-report verification must establish the
observations from a fresh run at the actual main commit. Existing reports are
not rewritten to add missing observations.
