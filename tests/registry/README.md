# Test registry

`registry.json` is the checked-in behavior index for the current workspace
test corpus. It registers JSON cases, stateful scenarios, compatibility
cohorts, policy checks, metadata probes, and individual named package tests without
changing how any of those tests execute. Schema 2 also owns reviewed
`release_commands`: package names, compare profiles, supported options, policy,
releasability, and explicit release case selections. Registry hashes cover this
release policy together with behavior ownership. Package versions still come
from each current `moon.mod`. The generated `release-profiles.json` sidecar is
a compatibility artifact and must not be used as an independent current input.

Use the [registered package report adapter](../packages/README.md) to execute
named package-test bindings and obtain the same report/metadata shape consumed
by the [change coverage audit](../coverage/README.md). A registry row records
the required assertions; only a matching execution row supplies their evidence.

The registry package exposes the following integration points:

- `load(path)` decodes the machine-readable registry;
- `entry.binding()` decodes its closed, typed implementation reference;
- `entry.evidence_ids()` provides canonical typed execution IDs and explicit
  reviewed aliases without accepting unqualified scenario, cohort, or test names;
- `validate(registry)` checks entry shape, duplicate behavior IDs, supported
  implementation kinds, evidence levels, observations, and backend claims;
- `validate_case_bindings(registry, case_ids)` compares registered JSON case
  IDs with IDs discovered by a case loader and reports orphan rows in either
  direction.
- `validate_selected_cases(registry, cases, root=...)` verifies every executed
  current case against its registered source, comparing the entire decoded
  canonical body. Unknown IDs and altered bodies using an existing ID fail;
  an alias selects the canonical case and does not replace its semantic ID.
- `case_sources(registry)` selects the canonical workspace case files;
- `implementation_ids(registry, kind)` selects named implementation bindings;
- `validate_source_bindings(registry)` discovers package test declarations,
  command metadata probes, cohort specs and scenario dispatch references to
  reject both unregistered sources and obsolete bindings.
  It also checks exact case-file/command/platform bindings, executable dispatch
  branches, package backend declarations, and lifecycle test references.

Source discovery tolerates only a typed ENOENT when a concurrently removed
entry disappears after directory enumeration. A missing registered declaration
still fails as an orphan binding. Permission, non-directory and other failures
remain fatal; a transient fixture cannot suppress a reviewed source obligation.

Behavior IDs are stable identifiers. Existing JSON case IDs remain unchanged;
the registry prefixes them with `case:` to keep their implementation category
explicit. Scenario, cohort, policy, metadata, and package registrations use
their own stable prefixes.

Registry entry counts include JSON cases, package tests, metadata probes and
harness scenarios. They are not command or successful-execution counts. Use a
selected run's report for execution totals and its registry fingerprint for the
corresponding corpus revision.

`oracle_profile` is an identity reference only. A runner must resolve that
reference to an immutable oracle profile before reporting upstream differential
evidence; a non-empty registry value is not a substitute for digest
verification.

`associations.json` records non-import fixture/scenario/cohort/policy/catalog/
release relationships used by the content-bound scope selector. Child-command
artifact prerequisites are distinct from retested command behaviors. Unknown
association syntax widens to full; malformed data cannot become empty scope.
`boundaries.json` indexes every current registered rejection's support document,
canonical ADR, current limit and unlock condition. Its same-ID rejection
references are requirements for real execution, never passing results. The
scope intent embeds the applicable records and preserves old-side replacement
obligations. See [scope contracts](../scope/README.md).

The workspace runner validates this registry before loading a suite. It compares
the registry's JSON-case bindings with the canonical workspace case corpus. A
smaller manifest may select registered cases but cannot introduce new bodies
or weaken registered assertions. Historical replay uses the frozen historical
corpus and is explicitly separate from current execution.

`lifecycle.json` records harness lifecycle evidence separately from command
semantics. Each entry names the exact test that proves its assertions, or
records a deferred condition and the remaining limitation. A classification
unit test is never presented as an end-to-end failure injection.
The source validator requires every nonempty lifecycle reference to identify
both an existing named test and a registered package-test binding. Proven rows
need explicit assertions; deferred rows need explicit limitations.

`platform-exceptions.json` records package tests whose bodies skip assertions
on excluded hosts. Each exception names its exact source, applicable platforms,
and reason. Registry refresh seeds these declarations for new bindings; source
validation rejects stale, mismatched or orphan exceptions. Changes to an
existing exception require a reviewed registry update. Unrestricted package targets require both
Native and Wasm; an explicit `supported_targets` declaration constrains them.
The retained GNU host cohort is Linux-only. A skipped test does not establish
coverage merely because its package test command exits successfully.

Every workspace and release report directory contains `run-metadata.json`.
Case rows reference its `run_id`, registry hash, artifact identity and, when
applicable, oracle profile. The record captures Git revision and dirty state, the live Moon
toolchain, canonical manifest/corpus hashes, sorted artifact content hashes,
safe environment fingerprints, host identity and execution timestamps.
Unavailable fields remain empty and keep reproducibility partial. Existing
report output is immutable: a filesystem lock rejects simultaneous writers,
and a later writer must choose a fresh report directory.

`refresh.mbtx` discovers exact package-test references from named MoonBit test
declarations and seeds defaults only for new typed bindings. Every field of an
existing reviewed row remains unchanged, including behavior identity, aliases,
status, observations, oracle and evidence requirements. Removed or renamed
bindings fail refresh and require an explicit reviewed identity migration.
Existing JSON behavior rows and release policy also remain unchanged; validation
reports source drift instead of silently weakening requirements. The script
validates the complete result before writing the registry and compatibility
release metadata sidecar.
Adding a test registration does not certify that its assertions cover a
changed behavior; coverage audit must still inspect the run evidence.

Every supported contract requiring Native and Wasm also requires
`backend-pair` evidence, independent of implementation kind. JSON contracts,
stateful scenarios, metadata probes and named package tests each have an
executor that compares actual observations from both backends. Native-only
harness tests and registered rejection boundaries do not invent a second
backend requirement. New package bindings receive the pair requirement when
their package supports both targets; refresh never removes reviewed evidence.

The explicit `registry strengthen-backend-pairs` migration adds the missing
pair requirements to previously reviewed dual-backend contracts, aligns each
scenario with its registered case platforms, and imports reviewed package
platform exceptions. It then discovers new package bindings and validates
ownership before writing. Run this migration once when adopting the new pair
executors; ordinary refresh remains a metadata-preserving operation.

The one-time `migrate_release_metadata.mbtx` imports the reviewed schema 1
release metadata into schema 2. It refuses already-migrated registries, so
later edits to a compatibility sidecar cannot overwrite authoritative policy.

`baseline.mbtx --freeze <commit>` creates the migration baseline from an
explicit Git revision and refuses to overwrite an existing baseline.
`baseline.mbtx --verify` checks hashes for historical manifests and report
evidence. The baseline describes the migration starting point; current run
metadata describes each later execution.
