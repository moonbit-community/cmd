# Frozen publication snapshots

Historical design reference, retired 2026-10-26. The mechanisms below are no
longer active entrypoints or publication requirements. Existing frozen files
remain unchanged. Use [current acceptance](README.md), `latest.json` and its
independent current expectations; do not generate new freeze/receipt archives.

Publication freezing and historical replay have different evidence meanings. A
new publication must pass the live exact registry, MoonX and semantic gates.
Recovering an old corpus from Git establishes its source contents only; it does
not recreate an old execution or prove that the historical release passed it.

## Exact registry verification

The freeze evidence document retains checksummed index receipts, but those
files are not authoritative. Before accepting each exact command coordinate
or core coordinate, the runner uses the released MoonBit async/http client to
query the fixed official HTTPS manifest endpoint and download the exact source
archive:

    https://mooncakes.io/api/v0/manifest/cli/<command>@<version>
    https://download.mooncakes.io/user/cli/<command>/<version>.zip

These paths follow RegistryClient::module_manifest and
RegistryEndpoints::package_archive in the official Moon implementation. Both
responses must be HTTP 200; redirects, transport failures, a different module
or version, yanked versions, invalid checksums, receipt disagreements and
archive SHA-256 mismatches reject the freeze. TLS uses system trust roots.
Registry URL environment overrides and receipt-supplied endpoints are not used.
Verified response details are retained as content-addressed JSON files beneath
the evidence directory's verified-registry directory.

The candidate's cases and release profile must match the authoritative registry.
Run metadata is decoded using the complete shared schema and independently
validated; a complete reproducibility label does not bypass missing toolchain,
artifact, policy, environment, timestamp or oracle evidence. The selected sealed
--oracle-profile is checked against the tracked recipe binding and the actual
immutable Docker image and inventory before differential evidence can be frozen.

## Migration provenance

The pure MoonBit migration entry is:

    MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/release_runner/migrate_historical.mbtx -- f54baac45730f5ded956ceb41f353b77fdd5c34e

The explicit revision must equal tests/registry/baseline.json. Historical
executable manifests use their last recorded Git revision at or before that
baseline; every corpus source is recovered from that same revision. The
current published baseline uses the baseline revision and its frozen metadata
overlay. Missing source history is an error. No historical manifest bytes are
rewritten, and no unknown historical semantics are reconstructed from today's
workspace files.

Each executable manifest has these sidecars:

- .cases.json: resolved case definitions without mutable file references.
- .provenance.json: source revision, source paths, manifest/corpus hashes and
  an explicit source-snapshot-only interpretation.
- .registry.json: the registry at migration time; this is ownership context,
  not a claim that the registry existed at the historical release date.
- .sources/: exact source bytes stored by their SHA-256.

The two original helper JSON documents are source inputs, not independently
executable publication manifests. They retain their original bytes and appear
in source archives whenever the historical corpus references them.

Replay accepts only the recognized current pointer or historical location. It
checks sidecar hashes and re-derives the full corpus from Git, so rewriting a
case plus its local hash is insufficient. An old source snapshot can still
expose a historical defect or unsupported schema; such a failure is retained
as a historical replay limitation rather than silently repaired. Replay uses
the archived registry identity and records its hash rather than validating
historical source references against today's workspace. New differential
claims still require that registry's explicit case/profile binding and the
current reviewed oracle recipe, immutable image and version verification.

## Later publication rollover

Freezing a new publication preserves the outgoing current manifest and its
sidecars byte-for-byte under a new historical release ID. The replacement
current snapshot binds its resolved selected cases to the committed candidate,
registry and Git revision used by the validated evidence. Historical files
cannot be replaced. A directory lock excludes competing freezes; files are
staged before replacement and the manifest pointer moves last. A partial
filesystem failure makes the inconsistent pointer fail provenance validation
instead of making a semantic pass claim.

An explicit candidate `release_scope` produces a `verified-partial-publication`
snapshot. Its provenance identifies the preceding committed current snapshot
as well as the new candidate and registry. Replay validates that predecessor
through its existing provenance, then reconstructs the exact merge: selected
command coordinates and cases come from the candidate; all other coordinates
and case definitions come from the predecessor. The published inventory remains
complete and contains no release scope. New receipts and execution evidence
prove only the selected publication, not a new release of retained commands.

The same live-registry, clean-source, immutable-oracle, case-observation and
atomic rollover requirements apply to full and partial publication. A supplied
hash cannot authorize changing an unselected coordinate or frozen expectation.
Platform-specific cases require applicable-host results; a skipped or foreign
platform row cannot satisfy their acceptance.

These changes do not publish any package and do not retroactively add
immutable-oracle acceptance evidence to old reports.
