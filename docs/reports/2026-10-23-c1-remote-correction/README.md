# C1 remote correction

Status: correction in local validation; C1 remote acceptance remains pending.
The preceding [C1 implementation report](../2026-10-23-c1-scope/README.md)
records its original local evidence and remains unchanged.

## Recorded first PR execution

The user authorized one initial push of
`c6f271566119857085caa4879a807d8c67b826c3` to
`codex/comprehensive-c1-scope`, followed by creation of
[PR 43](https://github.com/moonbit-community/cmd/pull/43).
Its [first run](https://github.com/moonbit-community/cmd/actions/runs/39910455893)
uses synthetic merge `642c95054f91576ace9a78cf6cbb01fd30371169`, with parents
`4180e527b8673e51dc0127d1747e27f2b3b7e95c` and the authorized head. Its tree
`c2e4b453e38ae2f8d807f8d083c4f0652d6afe7f` matches the candidate tree.

Windows job `120271987540` failed during reviewed coverage requirements before
check/test. The fresh disposable-index comparison reported a worktree content
or mode difference; its original diagnostic did not name the path or record
conversion settings. No Windows runtime report was produced. The precise
Windows file cause remains unconfirmed. Both macOS and Linux passed their full
platform jobs. The final coverage job rejected the failed three-platform
matrix before performing semantic coverage aggregation. C1 remains unaccepted.

Raw PR, run, job, merge identities and logs are retained under
`/private/tmp/cmd-c1-remote-evidence-2026-10-23/pr43-run39910455893/`.

## Corrections and proof boundaries

Git checkout may apply system `core.autocrlf` conversion. Suppressing system
configuration while freshly hashing the worktree can then reject legitimate
CRLF checkout bytes. A fixture-owned Git configuration and real Git checkout
reproduce that mechanism without changing host configuration. The adapter
projects only closed, Git-normalized checkout scalar values into its hardened
command boundary. Ambient `GIT_*` overrides remain blocked. The fresh index
still rejects actual equal-length content edits, changed link text, hidden
index flags and applicable mode changes. Failure diagnostics name contained
paths, status and modes without printing file contents or environment data.

The Linux receipt now includes the already executed `gnu-native` summary and
metadata. That report proves its registered supplementary diagnostic only;
it cannot prove semantic parity, a contract, backend pairing or rejection.

Frozen publication has its own complete proof subject. The current frozen
manifest selects 1,028 immutable case bodies and 78 exact coordinates. Frozen
registry requirements, case owners, actual verification classes, observations,
platform skips and sealed oracle identity are checked independently of current
source obligations. Published Wasm execution requires its own valid Wasm
artifact hash; a Native hash and matching row labels cannot substitute for it.
A matching case ID alone cannot authorize reuse of an old
body. Empty, partial, repeated or substituted publication evidence fails even
when no current behavior independently requires published evidence. The audit
retains its publication proof and findings in `.published.json`.

The Mac global test counts and registered execution counts differ by two
Native/two Wasm tests. Retained inventories identify both as registered
Windows-only `commands/mv/link_wbtest.mbt` tests (indices 2 and 7); their guarded
bodies are counted by global testing but correctly omitted from Mac package
evidence. They remain Windows obligations. JS/Wasm-GC each retain their two
`core/jq_filter/filter_test.mbt` tests.

A later full parallel test run exposed an existing source-registry scan race:
a temporary `core/netops-cd-status-*.url` fixture disappeared between directory
enumeration and type inspection. The scanner now tolerates only typed ENOENT
for an enumerated entry. Missing registered test declarations still produce
orphan findings; permission, non-directory and non-filesystem errors remain
fatal. Deterministic regressions cover actual enumerate/delete behavior and
explicit error classification. No command implementation or core test changes
are needed to make this scan robust.

## Historical protocol replay

The corrected high-level publication proof passed against the original run's
real Linux observations: 1,028 selected cases, 78 exact coordinates, 1,028 rows
and zero findings. The actual rows contain 544 contract passes, four contract
platform skips, 441 differential passes, 36 rejection passes and three rejection
platform skips. The replay binds old synthetic merge `642c9505`, its actual
run ID `release-1792737998243`, all ten receipt-listed hashes, four byte-matching
frozen inputs and the sealed oracle profile. Its proof is retained at
`/private/tmp/cmd-c1-frozen-replay-20261023/replay-1792740013873/published-proof.json`.

The Linux artifact is `12484526563`, advertised size 277,529,840 bytes and
GitHub SHA-256
`bf413efad5b256b3f9ec741622d1623024f39269447898f8c2419b513b29e7eb`.
Eleven selected protocol entries were fetched by verified HTTP byte ranges,
passed ZIP CRC validation and matched their receipt/source hashes. The full
archive transfer stopped after 90,685,440 bytes; its complete local SHA-256 is
not verified. The selected replay is a historical protocol diagnostic, not
acceptance of that failed PR or the corrected source. Failure logs, the partial
archive and explicit transfer status remain preserved.

These changes affect only scope/coverage/registry infrastructure and current decision
documentation. Command/core source, package versions and published inputs are
unchanged. Exact corrected-commit local validation, required PR checks and
actual-main acceptance must be recorded before C1 can complete. The initial
push authorization does not authorize another commit's bootstrap push.

## Correction validation before commit

The host toolchain completed registry refresh, interface generation, formatting,
all-target warning-denying checks and all-target tests. The registry contains
1,728 behaviors. Tests passed: Native 593, Wasm 287, JS two and Wasm GC two.
The thirteen added Native harness regressions cover checkout projection,
supplementary receipt membership, complete frozen publication proof and the
source-discovery race. The historical publication replay above also exercised
the actual 1,028-row protocol through the corrected high-level validator.

The released CI toolchain (moon `0.1.20261012 (748b63c)`, moonc
`v0.10.15+943464bfa`) passed Native warning-denying checks and all 127 selected
scope/coverage/registry tests, interface generation, CI harness formatting and
all ten automation formatting checks. The fourteen actual generated interface
outputs restore the pinned spelling; no public interface or command/core source
change remains. The normalized graph has 164 nodes, 768 edges and no
uncertainties, with semantic digest
`8e662fb8cbc2ed0f39ecf155fcb5d81a959e22c9d4442123a785ccdc32f807fd`.
The isolated source archive has SHA-256
`a765603094db65339acb58527985f7e0e39b224721cee7bf1dc5050b105f3257`.
Logs and generated output hashes are retained under
`/private/tmp/cmd-c1-repair-pin15-20261023/`.

The host toolchain's public v3 package graphs and the CI toolchain's public v2
graphs normalize to identical canonical bytes (SHA-256
`dd51d577bca5c24a70997fe7e9df5acb450e40acf0e088ab2684b86701d23419`).
An independent review then identified the missing published Wasm hash guard.
The Native-only substitution regression failed before that guard and passed
afterward. Host and pinned CI coverage checks and all 52 coverage tests passed
again; final pinned interface generation and formatting left the fourteen
interface hashes unchanged. This two-file refinement is retained as
`final-proof-patch.tar`, SHA-256
`985a59dd4ce0fab730770339b83d8d7a7cbc5b3765d9c3e63967a91a96c887cc`,
with its source hashes and step logs beside the original rehearsal evidence.

Exact corrected-commit local reports and the honest partial audit remain
pending. These pre-commit results do not bind a future commit or satisfy required
remote platform execution. An earlier diagnostic export included an AppleDouble
sidecar and failed source decoding; the clean export excluded filesystem
sidecars without modifying product source, and both diagnostics remain retained.
