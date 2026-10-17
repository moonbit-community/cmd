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
| The first CI run could not recover historical Git sources | CI fetches full history; frozen bindings still compare against the original committed bytes. Windows checkout preserves JSON bytes without line-ending conversion. |
| Windows paths misclassified frozen published manifests | Frozen selection and Git source lookup use normalized repository-relative paths. Tests retain rejection of live, custom and candidate locations. |
| A report-summary test corrupted the Moon test event stream | Summary rendering is pure and separately asserted; the CLI still writes the same summary and exit status. |
| Successful oracle comparisons lost their verified identity | Preflight binds the complete immutable oracle identity before execution. Finalization verifies the same identity and inventory, and rejects drift. |
| Windows scenario request JSON escaped temporary paths | Only harness-authored network request arguments are decoded and normalized; other arguments and raw captures remain comparison evidence. |
| Timestamp observation could perturb a later hard-link alias | Snapshot metadata is collected before any content reads. Baseline reads synchronize timestamps before the baseline is resampled. |
| Repository reads interfered with the rejected-touch interval | The exact atime/mtime assertion runs in a private temporary fixture. Raw timestamps and bytes are retained; pair evidence compares the validated unchanged relation. |
| HTTP listener cleanup was conflated with socket address reuse | A real HTTP request is followed by task cancellation, joining and owner-scoped listener cleanup. A listener-table observer must see the active fixture before the request and no LISTEN owner after cleanup. Missing or malformed observer results fail; retries and skipped assertions are not used. |
| Generated indexes could not read sources on another Windows drive | The live case loader and corpus fingerprint share absolute-aware reference resolution. Frozen Git snapshots still reject absolute, UNC and drive-relative references. |
| Windows regression fixtures used inconsistent path separators | Handcrafted coverage bundles and workspace path expectations use the same host normalization as the real loaders; the missing-pair rejection remains strict. |
| Cold asset resolution imposed a new help contract on old releases | Warmup records the historical exit status and requires exact asset bytes with confirmed cleanup. Actual selected smoke and contract assertions remain independent and strict. |

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

The first remote run, [38571227661](https://github.com/moonbit-community/cmd/actions/runs/38571227661),
tested `a69d39b4175f099365437f3562b4aaff5bca3d63` and failed. Its Linux oracle
comparisons passed 418 cases on each backend, but the run metadata had lost
the verified profile ID and digest, so these runs were correctly not accepted
as reproducible evidence. The Windows and macOS failures above were recovered
from the uploaded artifacts and job logs. This failed run remains diagnostic
evidence, not final acceptance.

Local timestamp controls found changes in 17 of 21 repository-directory
trials, including synchronized reads, and zero of 21 equivalent temporary-
directory trials. This isolates a directory-dependent interference condition;
it does not identify a particular indexing or synchronization service. The
original failure, controls, and subsequent isolated scenario results remain
under the local evidence directory.

After these CI repairs, local package validation passed 387 Native, 217 Wasm,
2 JavaScript and 2 WasmGC tests. The affected filesystem and network scenarios
passed direct Native/Wasm comparison (four report rows, including the two
registered legacy aliases). Registry refresh records 1,332 behavior entries.
The all-target warning-denied check, harness formatting, generated interfaces
and workflow syntax checks also passed. This is local repair validation;
cross-platform acceptance still requires the subsequent CI run.

The second run, [38706627835](https://github.com/moonbit-community/cmd/actions/runs/38706627835),
tested `894f21251013d6a269bf97aee588cd930bd1a594`. Its macOS historical replay
and full backend-pair suite passed (627 passing rows and two registered skips),
but the HTTP lifecycle connection probe still succeeded after cleanup. The fixture now
owns an explicit listener-close defer, while the refused-connection assertion
remains strict. Official async 0.22.4 archive and local cached archive SHA-256
matched; dependency-source drift was not established. The focused local
testkit suite passed all 54 tests after this ownership repair.

The second run also exposed an absent `MOON_HOME` in CI: exact MoonX warmup
exited successfully, but artifact hashing could not locate its cache. The
workflow now explicitly uses the hosted runner's Moon installation root for
both operations. These additional repairs require a new remote run; neither
failed run is final acceptance.

The third run, [38709128636](https://github.com/moonbit-community/cmd/actions/runs/38709128636),
tested `454bd34`. Linux passed all package tests, both fixed-oracle runs and
the exact published differential (801 semantic, 36 boundary, four registered
skips, zero failures). Cold smoke stopped at the frozen `sh@0.2.0` package,
whose unsupported `--help` returns status 2; its actual invocation and diagnostic
were retained. Resolution now avoids treating this warmup as a new help contract.

macOS still failed the connection probe after cancellation-only ownership, so the lifecycle
test now follows the explicit group-owned cleanup already used by production
scenarios. Its refusal assertion remains unchanged. Windows additionally found
cross-drive corpus loading and two path-expectation defects; the repairs above
keep historical provenance and coverage validation strict. Package-test logs
are uploaded immediately after that stage so later diagnostics do not depend
on completion of the entire workflow.

The mandatory product-change coverage gate in `AGENTS.md` applies to changes
under `core/` or `commands/` that affect behavior, APIs, support or versions.
This repair changes the harness only. The audit's integration tests still
exercise real committed Git ranges, clean/dirty checkout checks, substituted
case bodies and missing evidence; their success proves the gate protocol, not
command or release compatibility. No package publication was performed by
these harness repairs. The user subsequently authorized publication of the
upgraded command packages; its candidate, coverage and registry acceptance are
tracked separately in the 2026-10-15 metadata-release report.

The fourth run, [38711916498](https://github.com/moonbit-community/cmd/actions/runs/38711916498),
tested `bd359d1`. macOS and Windows passed all 389 Native, 217 Wasm, two
JavaScript and two WasmGC package tests. Linux still reported a successful
post-cleanup TCP connection. That probe cannot distinguish a retained listener
from a connection established using the freed ephemeral port. The test now
observes LISTEN ownership directly with a positive control before the real HTTP
request. This change still requires three-platform acceptance.

On resumption on 2026-10-17, the fourth run was complete: macOS and Windows
passed every workflow stage; Linux failed only the HTTP package test. Linux
also passed the exact published differential with 801 semantic results, 36
boundaries, four registered skips and no failures. The corrected listener-table
test passed all 56 local Native testkit tests. Registry refresh now records
1,335 behaviors. These facts do not substitute for a new remote run of the
listener-table correction.

Final source acceptance is now established by
[run 39041842874](https://github.com/moonbit-community/cmd/actions/runs/39041842874)
at `c619ae71ae92706d6d56cdd6c73c17f270a17230`. Linux, macOS and Windows each
passed 393 Native, 217 Wasm, two JavaScript and two WasmGC package tests,
including the listener-table correction. Linux passed 418 immutable-oracle
differentials and two boundaries on each backend with complete provenance.
The exact-source coverage audit has no findings or uncovered entries. Later
harness repairs keep collective option tags separate from individual coverage
classification and verify exact official archive redirects and receipt identity.

This accepting source also contains the separately authorized metadata-release
preparation. Its 79 successful uploads and subsequent published acceptance are
recorded in the [metadata release report](../2026-10-15-metadata-release/README.md).
They do not change the harness-only scope or the failed outcomes of the earlier
commits above. Grandchild ownership and the other stated observation limits
remain explicit boundaries.
