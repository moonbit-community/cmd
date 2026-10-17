# Unified metadata release

Closeout review: 2026-10-18 (Asia/Shanghai). Registry creation timestamps below
are recorded in UTC on 2026-10-17.

The authorized release has uploaded and verified `cli/core@0.6.0` and all 78
command packages from `c619ae71ae92706d6d56cdd6c73c17f270a17230`. All 79 official
archives match the retained local package ZIPs.
[Acceptance run 39045905149](https://github.com/moonbit-community/cmd/actions/runs/39045905149)
passed all required jobs on attempt 2, including three-platform exact MoonX
smoke, full Linux differential, Windows semantic cases and freezing. The
generated snapshot has been verified and imported. The new record commit must
pass its separate coverage audit before the final audited push.

## Scope and coordinates

All 78 published commands receive their next unused patch version. Shared
`cli/core` moves from 0.5.0 to 0.6.0 because the public gzip runner gained a
package-version argument; checksum metadata and the shared option catalog also
changed. Seventy-five command modules have source differences from their exact
published archives. The three unchanged command implementations, `md5sum`,
`sha1sum` and `sha512sum`, consume the changed shared checksum behavior.

| Previous command version | New published version | Commands |
| --- | --- | ---: |
| 0.1.0 | 0.1.1 | 15 |
| 0.1.1 | 0.1.2 | 15 |
| 0.1.2 | 0.1.3 | 1 |
| 0.2.0 | 0.2.1 | 39 |
| 0.2.1 | 0.2.2 | 8 |

The 72 existing core-dependent commands now request core 0.6.0. The six
independent commands remain independent. `timeout` stays local-only and is
excluded from publication. The initial planned coordinates and public registry
checksums are in [registry-inventory.json](registry-inventory.json); the
source/interface comparison against checksummed archives is in
[source-differences.json](source-differences.json). Public manifest responses
are retained in [registry-responses.json](registry-responses.json). The
2026-10-17 refresh found all proposed coordinates absent and all retained
published checksums unchanged. The publisher rechecked absence before each
upload. The final coordinate and checksum inventory is retained in
[publication-receipts.json](publication-receipts.json).

## Required acceptance

The standalone project contract is status zero, empty stderr, complete usage
on stdout for `--help`, and exactly `<command> <package-version>\n` for
`--version`. New exact metadata cases cover every releasable command. Help
captures must first pass the documented shape checks and match between Native
and Wasm; version bytes come from module declarations. They establish the
project contract without claiming upstream metadata parity. The closed-stdin
adapter does not measure unread input. Historical published expectations remain
frozen separately.

The source coverage declaration passed at the clean committed revision before
the reviewed push entrypoint sent that revision. Three-platform source CI,
including Linux immutable-oracle verification, then succeeded. Publication was
serial: core first, then commands in lexical order. Every completed upload
returned status 200 and was verified against the exact official registry and
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

## Retained preparation evidence

- Current source Native/Wasm metadata capture passed 237/237 rows for all 79
  local commands, including `timeout`. This dirty-tree capture prepares exact
  expectations; it did not replace the later clean committed push-audit evidence.
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
  The earlier reports are retained; fresh reports at the repaired source
  revision replaced them before pushing.
- The preceding HTTP listener repair is tracked separately in the
  [test-system closeout report](../2026-10-14-test-system-closeout/README.md).

## Final source gate

[Source CI 39041842874](https://github.com/moonbit-community/cmd/actions/runs/39041842874)
passed Linux, macOS and Windows at
`c619ae71ae92706d6d56cdd6c73c17f270a17230`. Each platform passed 393 Native,
217 Wasm, two JavaScript and two WasmGC package tests. This includes the HTTP
listener-table correction and coverage-classification regression. The clean
audit from `13beedeed6c9cb219e3382afe29b2f551e4ae0e8` covers 79 commands and
252 behaviors with no findings or uncovered entries.

Linux and macOS each passed 783 workspace backend-pair rows with two registered
platform skips; Windows passed 726 with 59 skips. The Linux pinned oracle passed
418 differential cases and two boundaries on each backend with complete
provenance. Its image digest was
`sha256:f82510ba6c5c5ff537008d5b9dbbf7799515b226e7c75493b79fe7e9cb56f8c2`;
its version-inventory hash was
`38c23cbc4494abd4279bb8669320a691273dbb6cd0c6773935fb9851837b316f`.
These source checks and their historical-consumer runs do not establish new
published-version acceptance.

## Publication and recovery evidence

The receipt export records 79 successful uploads, each with
`Server status: 200 OK`, exact registry verification and a checksum match
between the official archive and its retained local ZIP. The source is the
validated revision above; the candidate file SHA-256 is
`a127aa94ae301e84b3a6354cdb8addf50d388f555479d8cd822efc30e0a4b636`.
Official registry creation timestamps range from
`2026-10-17T15:11:51.579978+00:00` for core to
`2026-10-17T15:37:43.096372+00:00` for zcat, the final command.

Three interrupted attempts were retained and reviewed before resuming:

- `base32@0.1.2` failed its extracted-package check before upload because the
  local registry index had not yet resolved core 0.6.0. Exact-coordinate 404
  and an account-scoped registry update preceded the successful retry.
- `gunzip@0.1.1` failed TLS connection establishment before an HTTP publication
  request. Its empty stdout, original error and an independent exact-coordinate
  404 were retained before retrying successfully.
- `wget@0.2.2` had an unknown request/response-body transport outcome. It was
  not classified as a pre-request failure. Repeated manifest and archive 404s,
  followed by a refreshed official version index without 0.2.2, reconciled
  absence. The reviewed retry succeeded; the original ambiguous attempt remains
  separate from the successful receipt.

Resume reverified previous receipts without uploading them again. The final
export confirms all 79 local ZIPs match their official checksums.
An exact local `moonx cli/sh@0.2.1` probe also passed standalone help and version:
both statuses were zero, stderr was empty, help shape passed, and version bytes
were exact. Its stdin was closed; it does not measure unread open input.

## Published acceptance and snapshot

[Acceptance run 39045905149](https://github.com/moonbit-community/cmd/actions/runs/39045905149)
completed successfully on attempt 2 at the same validated source. Linux and
Windows passed on attempt 1; macOS passed on the targeted failed-job rerun,
attempt 2. The accepted reports all record clean source, complete
reproducibility and canonical candidate fingerprint
`2fb69a2d75af706f265c7ebb84ae9843222e1b026a622dcf8e740dbb87fe5211`.
The final differential report also records case-corpus hash
`6735fa0864ba9f29f519746eca558c1a100b02c07d905f4224e8cee666e97306`.

| Accepted report | Attempt | Contract | Availability | Boundary | Skip | Fail |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Linux exact smoke | 1 | 772 | 185 | 36 | 4 | 0 |
| macOS exact smoke | 2 | 772 | 185 | 36 | 4 | 0 |
| Windows exact smoke | 1 | 717 | 174 | 36 | 70 | 0 |
| Windows-only semantic cases | 1 | 2 | 0 | 2 | 0 | 0 |

Each full smoke report selects 997 cases. Availability and skips remain
separate from semantic passes. The four Windows-only rows supply the applicable
evidence missing from Linux; they do not require a Docker oracle.

Attempt 1 stopped macOS during exact `cli/sed@0.1.1` asset resolution: the
MoonX Wasm checksum download timed out before selected cases executed. This is
retained availability/infrastructure evidence, not a semantic mismatch or a
runner deadline. Its asset-preflight capture and job log remain under
`ci-acceptance/attempt-1/` in the local evidence directory. Failed macOS artifact
`12105389513` remains separate from successful attempt-2 artifact `12105498576`;
the accepted macOS report ID is `release-1792252066329`. No failing selected case
was converted into a pass by retrying it.

| Evidence | Observed result |
| --- | --- |
| Linux full published differential | 541 contract and 416 differential passes; 36 boundary passes; four Windows-only skips; zero failures |
| Combined semantic coverage | 997 unique selected case IDs pass on applicable hosts; no missing IDs |
| Postpublication oracle | `pinned-oracle-v1`; actual image and inventory identities match the verified hashes below |
| Freeze gate and artifacts | Passed; `release-frozen-snapshots` artifact 12106607024 and `release-freeze-evidence` artifact 12105819672 |
| Generated outgoing snapshot | `historical/published-2026-10-17-before-metadata.json`; exact bytes match the previous current manifest |
| Local import | Verified and imported; four intended current pointer files replaced, 86 historical files and 79 current source blobs added |

The Windows cases are `compat-filesystem-windows-chmod-boundary`,
`compat-filesystem-windows-ln-boundary`, `rm-final-parent-backslash` and
`repair-which-windows-pathext`. Their Linux skips do not satisfy freezing.
Combined Linux and Windows evidence covers every one of the 997 selected cases:
543 contracts, 416 pinned differentials and 38 boundaries. The successful freeze
re-verifies live official registry/archive identities and the actual Docker
image. The generated current manifest records all 78 commands as published,
core 0.6.0, and a resolved frozen corpus of 997 cases.

The [snapshot import receipt](evidence/snapshot-import-receipt.json) records
685 artifact files and preserves all 520 pre-existing files except the four
intended current pointer replacements. The outgoing manifest's SHA-256 is
`17c63d9ea3edf762e0372f09ac972589853ce70ae1549f3090d06be8a6facb6c`,
identical to the previous current bytes. The new current manifest's SHA-256 is
`be8d9e3df08375fd7d98c18103443fd46591de5e9f57479212384f84834f7f85`.

The postpublication oracle is `pinned-oracle-v1`, image
`sha256:f82510ba6c5c5ff537008d5b9dbbf7799515b226e7c75493b79fe7e9cb56f8c2`,
with version-inventory hash
`38c23cbc4494abd4279bb8669320a691273dbb6cd0c6773935fb9851837b316f`.
These identities were verified by the published run and freeze gate; they are
not inferred from the earlier source comparison.

The final tracked `evidence/` record contains `summary.jsonl` and
`run-metadata.json` for the three accepted smoke reports, Windows semantic
selection and Linux differential, together with the verified oracle profile
and inventory, successful CI metadata, exact-source coverage audit, official
registry responses, the snapshot import receipt and local sh result. The
publication receipt summary is linked above. The first macOS failure's empty
selected-case report and sed preflight capture are retained separately. These
files describe the observed results and their provenance; they do not embed
every raw case capture. Full raw streams, fixture captures, archive receipts
and original recovery diagnostics remain in the CI artifacts and ignored local
evidence directories.

The follow-up [record-update coverage declaration](record-update-coverage.json)
records the published-manifest impact separately from the source-release
declaration. Its target is the new record commit; the source acceptance above
continues to identify the published product revision. The reviewed push
entrypoint must audit that exact new head before pushing. This record does not
claim that final gate has already passed; its outcome is reported separately
without embedding a self-referential commit hash in this document.

The follow-up publisher helper refreshes the account-scoped registry once after
core verification and before the first pending command, preserving update
status and streams in a fresh attempt directory. The changed helper passed its
format check and compiled to its no-argument usage guard without executing a
publication. Generated interfaces remain unchanged. Product source remains
byte-identical to the accepted revision; this helper maintenance is separate
from the completed uploads.

Local execution logs and original recovery records remain under
`_build/verification/2026-10-17-metadata-release/`. The paused-state
[handoff](HANDOFF.md) remains historical. This release retains local-only
`timeout`, process-group/grandchild limitations and all existing support-record
boundaries; passing metadata contracts do not establish full GNU/POSIX parity.
