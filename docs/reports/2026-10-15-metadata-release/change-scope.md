# Metadata release change declaration

This is a reviewed coverage declaration, not an execution result. Each
`result: "pass"` is a required outcome under the audit schema. The audit must
verify the actual reports, exact committed revision, clean source tree,
current registry and case corpus before accepting the declaration.

The source range starts at `13beede`; pass that base explicitly to the audit
and push launchers with the final committed head. The declaration schema
does not contain Git refs. Earlier test-system repairs are outside this
publication-preparation range and retain their separate evidence.

This range updates package versions, matching version declarations and
documentation, and dependency pins to the reviewed core release. Metadata
support is selected explicitly for all 78 releasable commands. Shared-core
impact is declared for all 79 commands, including local-only timeout; it is
covered here by all registered metadata probes. No new operand behavior or
existing rejection boundary is declared by this source range.

The selected evidence requirements are the 79 metadata probes, 156 new
exact help/version JSON contracts, 14 refreshed existing version contracts,
and every registered receipt-validation test in acceptance_evidence_wbtest.mbt
and freeze_registry_wbtest.mbt when present, plus the Native audit regression
"audit uncovered classification keeps collective tags separate from individual
evidence" in entry_wbtest.mbt. Receipt and audit regressions are Native-only.
The audit repair keeps collective option/operand validation at declaration
scope while classifying each behavior by its own evidence requirements.
It must still reject missing global tags, missing report rows and missing
observations. Earlier reports with contradictory uncovered classifications
are retained separately and do not satisfy this declaration's fresh reports.
Requirements are copied from each registry row; global backend, evidence
and observation arrays stay empty so Native-only tests do not acquire a
Wasm requirement. Normalized help and version option identities are checked
against the catalog and new JSON bindings; command arguments remain --help
and --version. Closed-input captures do not prove unread open stdin.

Expected evidence files under _build/verification/2026-10-17-metadata-release:
audit-metadata/summary.jsonl, audit-pairs/summary.jsonl,
audit-receipt/summary.jsonl and audit-gate/summary.jsonl, each with its
matching run-metadata.json.
This helper neither creates nor accepts those reports. Missing, failed,
dirty, stale or incomplete execution evidence must fail the coverage audit.

Current and historical published snapshots are unchanged by this range,
so published_manifest_affected is false. Publication and exact-version
MoonX verification remain subsequent gates. Updating the published snapshot
after successful upload requires a distinct follow-up impact decision and
acceptance record; this declaration does not certify that future change.
