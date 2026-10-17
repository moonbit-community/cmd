# Unified metadata release

Prepared on 2026-10-17 after the user authorized publication. This is a pending
release record; no upload or final acceptance is claimed by its preparation
files.

## Scope and coordinates

All 78 published commands receive their next unused patch version. Shared
`cli/core` moves from 0.5.0 to 0.6.0 because the public gzip runner gained a
package-version argument; checksum metadata and the shared option catalog also
changed. Seventy-five command modules have source differences from their exact
published archives. The three unchanged command implementations, `md5sum`,
`sha1sum` and `sha512sum`, consume the changed shared checksum behavior.

| Published command version | Candidate version | Commands |
| --- | --- | ---: |
| 0.1.0 | 0.1.1 | 15 |
| 0.1.1 | 0.1.2 | 15 |
| 0.1.2 | 0.1.3 | 1 |
| 0.2.0 | 0.2.1 | 39 |
| 0.2.1 | 0.2.2 | 8 |

The 72 existing core-dependent commands now request core 0.6.0. The six
independent commands remain independent. `timeout` stays local-only and is
excluded from publication. The exact planned coordinates and public registry
checksums are in [registry-inventory.json](registry-inventory.json); the
source/interface comparison against checksummed archives is in
[source-differences.json](source-differences.json). Public manifest responses
are retained in [registry-responses.json](registry-responses.json). The
2026-10-17 refresh found all proposed coordinates absent and all retained
published checksums unchanged. The publisher must recheck before uploading.

## Required acceptance

The standalone project contract is status zero, empty stderr, complete usage
on stdout for `--help`, and exactly `<command> <package-version>\n` for
`--version`. New exact metadata cases cover every releasable command. Help
captures must first pass the documented shape checks and match between Native
and Wasm; version bytes come from module declarations. They establish the
project contract without claiming upstream metadata parity. The closed-stdin
adapter does not measure unread input. Historical published expectations remain
frozen separately.

The source coverage declaration must pass at the clean committed revision
before the reviewed push entrypoint sends that revision. Three-platform source
CI, including Linux immutable-oracle verification, must then succeed.
Publication is serial: core first, then commands in lexical order. Every upload
must return status 200 and be verified against the exact official registry and
archive checksum before the next upload.
The publisher preserves initial absence, upload and verification records.
Resuming creates a separate observation directory and compares each previously
verified archive with its first receipt; an unknown upload outcome stops.

After publication, `release-acceptance.yml` requires that exact successful
source SHA, runs three-platform exact MoonX smoke, and combines Linux full
differential results with the four Windows-only semantic cases. Skips do not
satisfy freezing. The Linux freezing job re-verifies the actual immutable image
and uploads the generated snapshot for review; it never publishes or pushes.
Official source archives may redirect once to the observed HTTPS distribution
host with the identical coordinate path. Host/path/scheme drift and checksum
mismatches fail verification.

## Preparation evidence

- Current source Native/Wasm metadata capture passed 237/237 rows for all 79
  local commands, including `timeout`. This dirty-tree capture prepares exact
  expectations; clean committed evidence is still required by the push audit.
- The generator rejects captures whose version bytes differ from current
  module versions. An older capture was rejected during preparation.
- All 242 immutable historical manifest/report files still match the migration
  baseline.
- Candidate generation validates 78 coordinates and 997 selected cases. The
  refreshed registry contains 1,494 behaviors. The declaration maps 252 affected
  behaviors, including 170 JSON metadata cases, two receipt regressions and one
  coverage-classification regression;
  these counts are scope records, not acceptance evidence by themselves.
- Local package tests passed 392 Native, 217 Wasm, two JavaScript and two WasmGC
  tests. The all-target warning-denied check, generated interfaces and workflow
  syntax checks passed. No generated public interface changed in this release
  preparation relative to its source base.
- Exact-source runs at `a32cc8c` passed 237 metadata rows, 783 backend-pair
  semantic rows (plus two registered platform skips), and 53 release-runner
  package tests. The audit incorrectly listed every behavior as uncovered by
  applying collective option tags to each individual row. The repair preserves
  declaration-wide tag validation and tests missing tags, rows and observations.
  The earlier reports are retained; fresh reports are required for the repaired
  source revision before pushing.
- The preceding HTTP listener repair is tracked separately in the
  [test-system closeout report](../2026-10-14-test-system-closeout/README.md).

Local execution logs are retained under
`_build/verification/2026-10-17-metadata-release/`. The paused-state
[handoff](HANDOFF.md) records the earlier interruption; it is not the current
acceptance status. Final source CI, upload receipts, exact MoonX results and the
new frozen manifest must be recorded here before this release is declared done.
