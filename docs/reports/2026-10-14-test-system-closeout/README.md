# Test-system recheck repairs

This report tracks repairs to the test-system reconstruction plan. It is not a
command release and does not replace historical command acceptance reports.
No command implementation, shared product code, package version or published
coordinate changes are part of this repair.

## Repair scope

| Finding | Repair and regression evidence |
| --- | --- |
| Unregistered or substituted cases could claim coverage | Selected cases must match their registered canonical bodies. Same-ID substitutions and unknown bindings are rejected. |
| Reviewed registry metadata was lost during refresh | Existing identities, aliases, requirements, observations and release policy are preserved; orphan references fail. |
| Dual-backend contracts lacked direct comparisons | Registry requires pairs; JSON contracts, scenarios, metadata probes and exact named package tests have explicit comparison executors. Package evidence is limited to test-process status and captured streams, not arbitrary internal values. |
| Missing lifecycle observers counted as passing tests | Applicable POSIX tests fail their prerequisites. Registered platform exclusions remain explicit. |
| Rejection snapshots missed same-content file replacement | Before/after identity observations retain device/inode identity. A real rejection-contract regression detects replacement. |
| Fixture startup and cleanup lost causal failures | HTTP/HTTPS startup has deadlines and protected direct-child cleanup; partial streams and cleanup failures are retained. Grandchild ownership remains a boundary. |
| Reports used host environment instead of effective child environment | Spawn boundaries record allowlisted inherited values and overrides. Metadata stores distinct host and execution fingerprints; empty or inconsistent execution profiles are incomplete. |
| Input changes could retain complete provenance | Start/end source, policy, environment and artifact identities are compared. Growing execution profiles alone are not input drift. |
| Partial metadata was accepted by audit or freeze | Both use the complete shared schema and recompute validity, including policy, Docker and executed artifact/environment evidence. |
| Release reports were optional or lost on preflight failure | Execution creates a unique default report directory and retains failure metadata. Report collisions never overwrite prior evidence. |
| MoonX coordinates substituted for actual artifact bytes | Exact cached Wasm asset bytes are hashed. Cold assets resolve before the initial fingerprints; warmup remains availability-only evidence. |
| Release policy had a separate mutable authority | Reviewed release metadata lives in the unified registry; compatibility outputs are generated. |
| Candidate and coverage selected different cases | Both use the release selection rules, including unconditional extras and empty selection semantics. |
| Candidate output depended on template corpus paths | Generation validates its actual output corpus and exact command/core module coordinates. Non-directory host files are ignored during discovery. |
| Frozen reports were not bound to selected cases | Freeze validates selected fixture identity, coordinate, observations and required evidence, including smoke rows. |
| Registry receipts could be self-authored | Freeze verifies live exact registry/archive information and checksums; receipts alone do not authorize a snapshot. |
| Staged oracle profile was ignored | Workspace, release and freeze paths validate the staged profile against the reviewed recipe and immutable image identity. |
| Historical replay depended on mutable current cases | Provenance-verified archived corpus, sources and registry are used for replay. Recursive references and overrides are resolved; cycles and tampering fail. Original manifests remain byte-identical. |
| Cyclic corpus fingerprinting could prevent failure reports | Fingerprinting detects recursive references and returns unavailable provenance instead of recursing indefinitely. |

## Verification boundaries

Local validation is performed on macOS with `moon 0.1.20261012 (748b63c)` and
`moonc v0.10.15+943464bfa`, using the CLI account through `MOON_HOME`. The first
complete repaired pass contained 381 Native and 217 Wasm package tests.
The baseline verifier confirmed 242 immutable historical manifest/report files.
Subsequent acceptance runs and their exact inputs are retained under
`_build/verification/2026-10-14-closeout/`; these are local execution evidence,
not a substitute for remote Linux/Docker evidence.

The checked workflow runs direct metadata, workspace/scenario and package
backend pairs on Linux, macOS and Windows. Linux builds the reviewed oracle,
seals a copied profile, and passes the resulting SHA-256 image ID to workspace
and exact published-consumer differential runs. A missing or mismatched oracle
must remain infrastructure failure. CI success must be established from an
actual run and uploaded reports before the complete plan is declared closed.

The mandatory product-change coverage gate in `AGENTS.md` applies to changes
under `core/` or `commands/` that affect behavior, APIs, support or versions.
This repair changes the harness only. The audit's integration tests still
exercise real committed Git ranges, clean/dirty checkout checks, substituted
case bodies and missing evidence; their success proves the gate protocol, not
command or release compatibility. No package publication is authorized or
performed by this work.
