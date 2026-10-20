# Stage 0: async 0.22.5 publication

Date: 2026-10-20

Published and verified `cli/core@0.7.0`, `cli/curl@0.2.3`, `cli/mv@0.2.3`
and `cli/wget@0.2.3` from
`7829269d1a3b751768e6f64a0d305cd76282ee02`. Local exact-version MoonX
acceptance passed. The other 75 published commands retain their previous
coordinates and frozen expectations; their workspace dependency upgrades
remain unpublished candidates. `timeout` remains local-only. No stage after
stage 0 is included.

## Source and publication

[PR #39](https://github.com/moonbit-community/cmd/pull/39) implements the
async upgrade, transfer failure/framing profiles, partial output, retries,
selected output paths and Windows link boundaries.
[PR #40](https://github.com/moonbit-community/cmd/pull/40) supplies scoped
publication, shared exact-MoonX scenarios and partial snapshot validation.

The product merge at `b1732423796562d9843fc3b1d331089e852e6ac5` passed
[source CI 39393087389](https://github.com/moonbit-community/cmd/actions/runs/39393087389).
The final release source passed Linux, macOS, Windows and coverage-audit in
[main CI 39404396152](https://github.com/moonbit-community/cmd/actions/runs/39404396152).
The [product audit](evidence/source-product-audit.json) and
[release-harness audit](evidence/source-harness-audit.json) retain their distinct
exact ranges. PR-only results do not substitute for these mainline runs.

Publication used the official CLI account, checked all four proposed
coordinates were absent, then uploaded serially in this order:

| Module | Version | Upload and registry result |
| --- | --- | --- |
| cli/core | 0.7.0 | Exit 0, HTTP 200, exact official archive checksum verified |
| cli/curl | 0.2.3 | Exit 0, HTTP 200, exact official archive checksum verified |
| cli/mv | 0.2.3 | Exit 0, HTTP 200, exact official archive checksum verified |
| cli/wget | 0.2.3 | Exit 0, HTTP 200, exact official archive checksum verified |

[Publication receipts](publication-receipts.json) record every coordinate,
source revision and archive SHA-256. Individual upload results, public
registry manifests, verification details, account and toolchain identity are
under [evidence/publication](evidence/publication/). Every upload returned
`Server status: 200 OK`; registry verification completed before proceeding
to the next module.

## Actual local MoonX acceptance

The macOS run used `MOON_HOME="$HOME/.moon-accounts/cli"` and the existing PATH
toolchain. It launched exact `cli/curl@0.2.3`, `cli/mv@0.2.3` and
`cli/wget@0.2.3` through MoonX, rather than workspace binaries.

- The 95-case scoped smoke selection produced 64 semantic passes, 25
  availability passes, one boundary pass, five platform skips and no failures.
  Availability rows are not upstream parity evidence.
- Separate `network-auth-cookie` and `network-transfer-boundaries` runs both
  passed the shared assertions for the two exact published network commands.
  These retain status, response prefixes, files, cleanup, Range/request counts,
  retries, selected filenames, raw requests and output error precedence.
- Each standalone version output matched exactly `<command> 0.2.3\n`.
- A real `moonx cli/mv@0.2.3 -- -T source destination` returned zero, removed
  the source entry and preserved the complete destination bytes.

The [smoke rows](evidence/local/smoke/summary.jsonl),
[network contract rows](evidence/local/contracts/summary.jsonl),
their matching run metadata and
[mv file effects](evidence/local/mv-file-effects.json) are retained. Local
platform skips are completed by the applicable CI hosts below, not counted as
local semantic passes.

## Published platform and oracle acceptance

[Acceptance run 39409393072](https://github.com/moonbit-community/cmd/actions/runs/39409393072)
passed every required job on its first attempt: three-platform exact MoonX
smoke, Windows-only contracts, pinned Linux differential and publication
freezing.

Linux differential produced 78 upstream-differential passes, 13 contract
passes, one boundary pass and three Windows-only skips. The independent Windows
run supplied two contract passes and the `mv-windows-wasm-links-boundary`
pass. Together these establish the required semantics for all 95 selected
IDs; smoke availability alone does not establish them.

The immutable oracle image is
`sha256:f82510ba6c5c5ff537008d5b9dbbf7799515b226e7c75493b79fe7e9cb56f8c2`.
Its [sealed profile](evidence/published/oracle-profile/profile.json) and
[version inventory](evidence/published/oracle-versions.txt) bind the image,
recipe and upstream distribution/source checksums. Relevant tools are
curl 8.22.0, GNU Wget 1.25.0 and GNU coreutils 9.11.

Windows used moon/moonrun `0.1.20261012 (748b63c 2026-10-12)` and moonc
`0.10.15+943464bfa`. Actual source Native/Wasm fixtures and published MoonX
fixtures observe file symlinks, directory symlinks, dangling links and
junctions, their targets, referent bytes, backups and open-stdin rejection.
The [Windows published rows](evidence/published/windows/contracts/summary.jsonl)
and matching runtime metadata retain that host distinction. Package
fault-injected Native backup recovery is not presented as a real CLI
post-backup filesystem failure.

## Partial snapshot and retained limits

The imported snapshot has kind `verified-partial-publication`, identifies the
committed predecessor, and preserves all 75 unselected coordinates and cases.
All 518 pre-existing historical files matched byte-for-byte. The outgoing
core 0.6.0 snapshot is archived as
`published-2026-10-20-before-async-0225.json`; earlier history was not rewritten.
The [import receipt](evidence/snapshot-import.json) records these checks.

The complete inventory remains 78 published commands: 39 at 0.2.1, five at
0.2.2, three at 0.2.3, 15 at 0.1.1, 15 at 0.1.2 and one at 0.1.3. The shared
core is 0.7.0.

Windows Wasm source-link moves and destination-link backups remain rejected
before prompting or mutation. [Issue #38](https://github.com/moonbit-community/cmd/issues/38)
retains the released-host fix and independent verification needed to lift that
boundary. [Issue #10](https://github.com/moonbit-community/cmd/issues/10) and
[issue #20](https://github.com/moonbit-community/cmd/issues/20) remain capability
trackers. Cancellation cleanup, descriptor identity, metadata, and the
unselected network/GNU extensions keep their documented limits.

The record update changes publication evidence and current documentation only.
Its coverage declaration selects the registered release-runner regressions
that validate full inventories, retained coordinates, frozen provenance and
acceptance evidence. The exact committed record revision requires its own
local audit and protected PR checks. These record tests do not reclassify
source or publication evidence as having run at a later documentation commit.
Gzip #27 and all subsequent roadmap stages remain untouched.
