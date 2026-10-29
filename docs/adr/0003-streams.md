# ADR-0003: Preserve Streams and Caller Locale

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-30
Revision: Consolidate shared ownership and internal execution state while preserving R-stage streaming, temporary-storage, matcher, metadata and failure contracts.

## History-led cleanup delivery (2026-10-30)

The user authorized incremental cleanup of A01-A12 below and normal branch
pushes after local checks. C01-C03 remain candidates; the dump-loop and core
API/async candidates receive further audit without product changes.
Delivery evidence is retained under
`/Users/winter/.codex/visualizations/2026/10/29/01a18848-fe88-7423-8793-7a3730b785e9/cmd-cleanup-20261030`.

Batch 1 retains A01/A02 and repairs A04. Architecture validation now checks the
driver boundary for production and both test import forms. Its negative
controls cover matcher and searcher, while allowing the executable to import
its driver and the mechanisms to import shared bytesearch. This does not add
test-only imports to runtime reachability or prohibit legitimate test cycles.

Batch 1 is commit `713b076`; required ubuntu-24.04, macos-15 and windows-2025
checks passed in run `40914956163`. A real injected searcher white-box driver
import now exits nonzero and records the forbidden dependency.

Batch 2 resolves A03 as an explicit boundary. Valid `--dfa-size-limit` values
now fail before input is opened; numeric parsing, including overflow and missing
values, retains its existing diagnostics. The fixed engine state-count limit
is unchanged. Enabling this option requires actual cache byte accounting and
budget/fallback execution regressions. README, help, the supported-option
catalog and the compatibility record agree; two command-level boundary cases
fix status, empty stdout and the full diagnostic. The first-release candidate
remains unpublished `cli/rg@0.1.0`.

Batch 2 is commit `1e9db36`; all three required checks passed in run
`40964402975`, attempt 2. The first Windows attempt failed four existing mv
PowerShell link observations at their 10-second deadline. Its full log is
retained; retrying that failed job passed without changing assertions or
deadlines. This does not erase the initial observation failure.

This option-contract correction intentionally changes help output. It is a
correctness fix with no speed claim. Its source and all 80 command artifacts
form the immutable corrected-contract baseline for the following cleanup
phase; the earlier audit baseline remains preserved. Cleanup comparisons must
retain equal outputs under that contract, including the help workload.

The initial A05-A12 candidate passed 1,707 release-Wasm tests, 118 Native
test-tool tests and 2,122 functional checks (19 platform skips). Its full
protection result was rejected: 155/160 rows qualified. Three stable rg
boolean-count controls exceeded the 5% limit in both windows:
`rg-pilot-late-prefix-hit-count` (20.44%/21.30%),
`rg-boolean-false-positive` (19.59%/18.81%) and
`rg-boolean-sparse` (20.27%/19.71%). `tac-stream-8m` and `tac-long-8m`
were unstable despite unchanged tac bytes. All 89 real-corpus tasks retained
output equality against pinned Rust 15.2.0 and qualified for stability and
the slowdown threshold. The small real-corpus cost was
`wiki-unicode-count` (4.38%/4.42%); unchanged `tac-multi-8m` measured
0.70%/4.30%. The overall candidate was not accepted.

Four source counterfactuals and a revised implementation are retained in
`rg-diagnosis`. Reverting A12 kept the three regressions; reverting A08 or A09
removed them in the diagnostic window, while reverting the driver cleanup
also changed the profile (one remaining 6.10% sparse-case observation).
This does not isolate a single source-level hot-loop cause. No regex or
boolean-count algorithm was edited. The evidence is consistent with a
combination-sensitive compiled result, not proof of a particular compiler
mechanism.

The revised A09 stores the optional canonical path directly in `Ancestor`,
removing the remaining single-field `Handle` wrapper and its comparison
method. Metadata failure still precedes the optional canonical-path lookup;
two absent canonical paths never count as a loop. This further simplifies the
actual representation without restoring dead code or adding layout padding.
Its diagnostic ratios for those three controls were 0.9899, 1.0028 and 0.9857.
Those small diagnostic windows are not full performance acceptance. Initial
source, artifacts, all failed windows and the complete 89-task report remain
under `cleanup-protection` and `cleanup-real`; revised validation uses separate
`final-*` evidence paths.

Batch 3 is commit `cd25293`: the upload forwarder removal and four additional
HTTP protection controls. All three required checks passed on the first
attempt in run `40971804014`.

The revised complete protection run qualifies 159/160 rows. Every registered
workload for the three changed commands (rg, curl and wget) is stable and
within the 5% slowdown boundary. The sole unqualified row is
`ln-symbolic-validation`: candidate/reference first-window MAD fractions are
9.16%/8.20% for roughly 9 ms complete processes, above the 5% limit. Its
window ratios are 1.0110/0.9938 and ln's complete artifact is byte-identical.
The full timing verdict remains **failed**, with no repeated identical run
to obtain a passing result. These commits deliver a correctness-checked PR
cleanup candidate; they do not claim full-registry performance acceptance,
mainline acceptance or published-coordinate acceptance.

The revised real-corpus comparison qualifies all 89/89 tasks, with complete
Rust-oracle output/status checks and both 12-pair timing windows. No qualified
loss reaches 3% in either the protection suite or this real matrix. The three
formerly regressing synthetic controls now have ratios 0.9877/0.9728,
0.9813/0.9791 and 0.9813/0.9771. Protection took 650.8 seconds; real preflight
49.0 seconds; the real windows took 553.7 and 552.2 seconds. Exact rows and
durations are in `final-verdict.json`, `final-real/verdicts.json` and
`performance-final-stages.json`.

Separate single-pair macOS peak-RSS observations are 33.63/33.77 MiB for rg,
32.31/32.39 MiB for curl and 32.80/32.63 MiB for wget (baseline/candidate).
Their outputs and statuses match. These are diagnostic observations, not a
resource acceptance window or evidence of a memory improvement. Existing
output-failure and temporary-cleanup regressions pass in the full suites.

### A01-A12 delivery checklist

| ID | Concrete change | Verification |
| --- | --- | --- |
| A01 | Delete the unused generic matcher replacement helper. | No semantic callers; batch 1 preserves all 80 complete Wasm artifacts. |
| A02 | Replace constant-disabled indexing success assertions with actual rejection cases. | Eleven indexing spellings/orderings and missing-value handling are exercised. |
| A03 | Reject the unused DFA byte-budget option and remove its stored field. | Exact positive/zero-budget command diagnostics, numeric errors, help/README/catalog/support agreement. |
| A04 | Enforce the driver import boundary across production and both test import forms. | Six negative controls and a real temporary searcher white-box import injection; all three CI hosts. |
| A05 | Remove indexing-only fields, mode and unreachable validators. | Rejection/error ordering and original parser expectations remain. |
| A06 | Remove thread/mmap state and the unused mmap mode type. | Accepted syntax remains; invalid/missing numeric cases and both option orders are covered, including valid UInt64 values that the existing parser clamps. |
| A07 | Make the remaining 19 driver argument types and `ParseResult` private; remove unused traits. | Strict compiler checking; 247 assertions retain their original expected values through direct pattern checks and a white-box context helper. |
| A08 | Replace unused ignore-origin payloads with the existing `Match[Unit]`. | Override, ignore, type and hidden precedence is retained in existing traversal regressions. |
| A09 | Remove unavailable device/inode, same-filesystem and stdout-identity paths; keep direct canonical ancestor evidence. | Metadata errors precede optional canonicalization; missing evidence cannot compare equal; identity rejection and symlink traversal regressions remain. |
| A10 | Replace `Mode::updated`, which discarded its receiver, with assignments. | Existing mode-order cases and an execution case where count overrides files mode. |
| A11 | Call `HttpWire::write_payload` directly at its three request-body callers. | Full local suites plus six qualified download/upload protection controls, including four new complete 8 MiB upload comparisons. |
| A12 | Move `path_strip_prefix` beside its six white-box/fixture references and replace the one-use `Ignore::path` getter with private-state access. | Original fixture values and path cases are preserved; no product API is widened. |

The final local correctness pass comprises 1,707 release-Wasm tests, 118
Native test-tool tests and 2,122 functional checks with 19 platform skips,
plus strict checking, interface/format regeneration and architecture inventory.
Only rg, curl and wget artifacts differ from the corrected-contract baseline;
the other 77 are byte-identical. C01-C03 are explicitly outside this implementation
list, with the follow-up evidence below.

### Candidate follow-up: dump input ownership (C01)

The identical 16-line `DumpState::read` methods are confirmed duplication.
Both bounded readers arrived together in `008ce12` (2026-10-11), rather than
surviving removal of an earlier shared reader.
Both retain a 64 KiB buffer, accept short reads, stop only on a zero read,
and cap each read at `min(65536, min(skip, 65536) + min(remaining, 65536))`.
The cap prevents consuming bytes beyond the requested input budget, including
stdin. State persists across files; moving that state into a per-file helper
would break combined-input offsets, partial rows and repeated-row squeezing.

Eight execution probes against the frozen command artifacts confirm the
following differences (`dump-probe/results.json` in the delivery evidence):

| Input | hexdump | od |
| --- | --- | --- |
| Zero byte limit and a missing filename | exits 0 without opening the file | opens the first source and exits 1 |
| Skip 10 bytes from a three-byte file | exits 0 and prints final offset `0000003` | exits 1 with the combined-input EOF diagnostic |
| Empty regular file | no output | prints final offset `0000000` |
| Skip two, read three across two `abc` files | renders `cab` in its canonical layout and final offset five | renders the same three bytes in its own selected layout |

The rendering owners also differ: hexdump feeds `Bytes` through a configurable
format program and final-address unit; od feeds `String`, owns width/endian/
floating-point and traditional-label behavior, and has a separate strings
reader. Existing `stream.read_chunk` does not accept this changing read budget.
A shared command loop would require new state access/callback plumbing and
must still preserve these separate finalization and error rules.

Decision: retain C01 as a candidate, with a recommendation to keep the two
small owner-local loops. The next useful pilot is narrower: investigate the
explicit `buffer[:count].to_owned()` materialization before `Bytes::from_array`
without changing input ownership. This source expression alone does not prove
two runtime allocations; the public constructor may reuse exclusive storage.
Any trial needs short-read/EOF/budget/output-failure tests and separate
hexdump/od workload and allocation observations. No dump source is changed.
The existing case files contain 60 hexdump and 61 od entries, largely covering
CLI/format behavior. Package tests cover feed/row state, but there are no
injected short-reader/output-failure tests beside these two read methods.
Those 121 case records therefore do not by themselves establish the contracts
needed to replace the loops with a new shared mechanism.

### Candidate follow-up: core visibility and async (C02)

The exported-API inventory's 18 zero-dependent-use functions/constants were
checked against same-package code, white-box tests, test-tool modules and
freshly fetched `cli/core@0.8.2` sources. This is a scoped review of that
inventory, not proof that every exported type/field/variant is minimal.

| Group | Actual evidence and disposition |
| --- | --- |
| `bytesearch.teddy_max_literals`, `checksum.Algorithm::hex_length`, `gzipops/cli.help` | Each has a real same-package production consumer but no dependent caller. The first two exports and the new adapter package arrived on 2026-10-28 and are absent at those coordinates in fetched 0.8.2. Good candidates for private visibility before the next core release; keep their implementations. Old 0.8.2 exported gzip help at `gzipops.help`, so a release still needs an explicit old-to-new API migration policy. |
| `contracts.command_catalog`, `find_contract`, `releasable`, `process_group_cancellation_available` | Catalog, lookup and release eligibility have actual test-runner validation consumers; the capability helper feeds eligibility locally. Runtime-command-only usage counts miss this ownership. Retain the validation API; consider only the local capability helper's visibility in a deliberate compatibility review. |
| `gzipops.decode` | Used by the benchmark tool's decoded-output validation. It is not a redundant alternative to the streaming product entry point. Retain. |
| `netops.url_host` | Used by proxy bypass evaluation and a white-box regression. Private visibility is locally possible; deletion is not. Already exported by 0.8.2. |
| `CookieJar::netscape`, `TransferResult::header` | The former is used by save plus eight white-box cases; the latter by content-disposition filename handling plus three cases. They also provide meaningful in-memory serialization/lookup APIs already exported in 0.8.2. Retain unless an intentional public API reduction is chosen. |
| `platform.current`, `is_terminal`, `terminal_policy_allows` | Locally feed platform selection and terminal policy; tests exercise the capability boundary. A current constant-false terminal capability is an honest unsupported boundary, not a speculative fallback to delete. |
| `platform.native_separator`, `accepts_separator`, `is_cross_device_error` | The first two have test-only local consumers; the last has no current code consumer. These are the strongest published deprecation candidates in this scan. All three exist in 0.8.2; local non-use cannot establish external non-use. |
| `time_zone.decode` | Used by zone-file loading and TZif regressions, with an existing published in-memory decoding contract. Retain. |

`Session::finish` has seven semantic references: sh (two), split (one),
`Session::run` (one), and three tests. Its body only checks/updates pending,
finished and exit state; it contains no async operation. No common trait or
function-value contract with `feed` requires async. The future-cleanup comment
is therefore an unnecessary implementation constraint, but the async function
type is already public in 0.8.2.

History confirms that the future-only async comment and the unconsumed
`is_cross_device_error` export both arrived in `6fff343` (2026-09-21).
Searching that original revision also finds only the error helper's
declaration, not a product caller. This is unused initial scaffolding, not a
currently necessary cross-device rename fallback.

An isolated probe made `finish` synchronous while retaining its generic error
effect and made `gzipops/cli.help` private. Strict workspace checking and all
1,707 release-Wasm tests passed. Complete artifact comparison changed sh,
make and split, in addition to the unrelated staged rg cleanup. Both probe
changes were restored. A preliminary narrower `raise ShellError` signature
also exposed an unreachable generic catch arm in a test; that result is kept
as evidence rather than suppressed. Neither probe establishes external API
compatibility or performance acceptance.

Recommended next decision: first approve adopting the visibility-only change for the
three unpublished exports above. A separate isolated probe of exactly those
three visibility changes passed strict workspace checking and left all 80
complete command binaries byte-identical to the frozen cleanup candidate;
the probe was then restored (`core-export-probe`). Separately choose whether to deprecate the
three unused/test-only published platform helpers and whether a future core
API revision should make `Session::finish` synchronous. Do not combine these
decisions with removal of useful serialization, decoding or catalog APIs.
C02 remains unimplemented; C03 also remains a candidate.

## History-led cleanup audit and isolated pilots (2026-10-30)

This review fixes its starting point at
`e568bdffc326f55ba71fd5428267587563ae56ee`, with a clean source checkout.
The original `performance-optimization-and-cleanup` checkout is not edited.
The isolated checkout is
`/Users/winter/.codex/worktrees/cmd-slop-audit-20261029/cmd`.
Evidence, source archives, all starting command binaries, diagnostic patches
and logs are retained at
`/Users/winter/.codex/visualizations/2026/10/29/01a18848-fe88-7423-8793-7a3730b785e9/cmd-slop-audit-e568bdf`.
No commit, push, merge, version change or publication is part of this audit.

### Scope and historical causes

The history inventory contains 257 reachable commits. Review followed the
history of each candidate with `git log -S`, blame and selected diffs, plus
workspace-wide package, exported-API and duplicate-body inventories. This is
not a claim to have semantically reviewed every line of every historical
revision. Current mechanical coverage is 80 commands and 124 packages. The
core/command source scan counts 390 implementation files / 86,302 lines,
236 test files / 35,807 lines, and 17 files named `*_data.mbt` / 5,214 lines.
These are physical lines including comments, not counts of removable code;
the filename-based data classification is not a complete generated-code audit.
The exported-API analyzer counts dependent-package use, not all same-package
or test-tool use. A zero in that inventory alone is not a deletion criterion.

| Historical step | Consequence checked against the current source |
| --- | --- |
| `5028c62`, then `1f3ca61` | `write_client_chunk` originally owned timeout/error handling. The responsibility now belongs to `HttpWire::write_payload`; the forwarding function survived. |
| `c048555` | Importing rg brought a large existing library surface, constant-disabled indexing tests, inactive feature state, and platform-identity alternatives. Imported code is not automatically unnecessary. |
| `e61d1c6`, `40efae2` | The old audit/sealing workflow was retired. Historical frozen release inputs remain evidence; they must not be classified as live product dependencies or deleted as duplicate fixtures. |
| `7f915a5`, `1f3ca61`, `7232784`, `3230632` | Shared kernels, command adapters and rg ownership were consolidated. Current references confirm actual reuse; the copied memchr package, old grep_regex adapter and sequential parallel-walker facade are already gone. |
| `0d65187`, `3393528` | Architecture inventory and strategy checks were added, but the explicit matcher/searcher-to-driver test-import prohibition is not enforced. |
| `6d4e569`, `ee3fc42`, `e568bdf` | Read budgets, cleanup ownership, lazy regex state and buffered I/O changed. Their tests and measured specializations must survive cleanup. Earlier findings about missing architecture tooling or already-removed wrappers are not current findings. |

The code-only diff from `987cf02` to this baseline is 315 files,
18,254 inserted lines and 23,119 deleted lines, including tests and scripts.
Net line count is neither a quality verdict nor proof of needless abstraction.

### Confirmed findings and dispositions

P1 denotes a misleading contract or a demonstrated validation blind spot;
P2 denotes verified cleanup debt. A proposed simplification is not an accepted
runtime optimization. Locations below refer to the fixed baseline unless the
pilot explicitly changes them.

| ID | Priority and evidence | Smallest cleanup and required gate |
| --- | --- | --- |
| A01 | P2, completed pilot. `internal/matcher/matcher.mbt:181` exported generic `replace` has zero semantic references, including tests. It arrived in `c048555`. Actual replacement uses `replace_with_captures_at`. | Delete the 24-line unused implementation and regenerate the interface. All 80 complete release-Wasm command binaries remain byte-identical. |
| A02 | P2, completed pilot. Four indexing tests in `internal/driver/flags_wbtest.mbt:953` return inside `if !false`, leaving success assertions unreachable. A deliberately failing assertion inserted after the return still yields a passing test. | Remove the unreachable tails while keeping all four test names and the existing missing-value rejection. Exercise eleven supplied indexing spellings/orderings against the actual unsupported diagnostic. This is stronger rejection coverage, not indexing support. |
| A03 | P1. `defs.mbt:148` parses `--dfa-size-limit` into `LowArgs.dfa_size_limit`; no product read exists. `search_pattern.mbt:88` hardcodes `dfa_state_limit: 10000`. `flag_defs_data.mbt:236` promises a size limit in bytes; existing tests assert only stored parser values. | Decide an honest contract: implement a real byte budget through the engine or explicitly reject/document the unsupported option. Do not reinterpret bytes as a state count. Update README, generated help source, catalog/support record and an execution-level budget regression together. |
| A04 | P1. `tests/architecture.mbtx:278,336` traverses/checks production dependencies only. Injecting `cli/rg/internal/driver` into searcher's white-box imports still prints `dependency checks passed`, with an empty failure list. The injection was restored. | Enforce the explicit matcher/searcher-to-driver rule over both production and test dependencies. Keep a negative control for each direction. This is a guard failure, not evidence that the current clean dependency graph has that violation. |
| A05 | P2. `defs.mbt:75` always raises for indexing. Assignments after its four calls, indexing-only fields, and the downstream compatibility validator in `plan.mbt:424` / `defs.mbt:395` cannot run through the current CLI. | Retain the flag names and current rejection/error order, including missing-argument handling. Remove unsupported execution state and its unreachable validators as one slice. Re-run parser-order and command-boundary tests; do not enable indexing. |
| A06 | P2. `LowArgs.threads` and `LowArgs.mmap` are written but never read. README and compatibility already state single-threaded, streaming behavior. | Preserve accepted syntax, numeric validation and last-option behavior; eliminate stored values and obsolete state types where possible. This is state cleanup, not a feature fix. Check help, invalid values, aliases and option ordering. |
| A07 | P2. The driver exposes 21 `pub(all)` declarations in `lowargs.mbt`, plus `ParseResult`, without dependent runtime users. A private-visibility probe exposes 34 strict compiler errors: five never-read fields and 29 unused trait implementations. | Remove genuinely unused state first, then reduce visibility in small groups. Keep test-only capabilities in white-box helpers. The blanket private conversion was reverted; adding warning suppressions would conceal the debt again. |
| A08 | P2. `IgnoreMatch` creates Override/Gitignore/Types/Hidden provenance payloads, but no consumer reads any variant. Removing its warning suppression produces four `unused_constructor` errors explicitly saying the variants are never read. | Keep Ignore/Whitelist/None decisions and all precedence rules. Trial a payload-free internal decision only after checking glob/ignore diagnostics and performance. Hidden-file filtering is live; deleting its branch would be wrong. No allocation or speed improvement is claimed by this audit. |
| A09 | P2. `sys/filesystem.mbt:116` always supplies `dev: None, ino: None`. Consequently `stdout_handle` never returns an identity handle, ID-based `Handle::same` branches have no production producer, and `--one-file-system` is rejected before the walker. Normal searches nevertheless call `skip_stdout`, which attempts metadata work before returning None. | Express the unavailable capability directly; remove dormant identity plumbing only as a bounded slice. Preserve canonical-path loop detection, unknown-entry kind queries, existing rejection diagnostics and the public-API unlock condition. This audit establishes source reachability, not a measured syscall/time reduction. |
| A10 | P2. `Mode::updated` ignores `self` and returns `new`; ten parser call sites use it as if it were a transition policy. Its comment confirms that every mode overrides the current one. | Replace the wrapper with direct assignments and retain competing-mode order tests. Do not invent a mode-transition framework. Rebuild and compare artifacts before accepting runtime effects. |
| A11 | P2. `core/netops/request.mbt:184` only forwards to `HttpWire::write_payload` at three upload call sites. Historical timeout/error ownership explains why the wrapper existed, but no responsibility remains in it. | Inline the three calls without changing file/stdin/bytes-body failure ownership. Retain timeout and upload regressions; include upload workloads in protection coverage. The prior failed timing experiment is not a current acceptance result. |
| A12 | P2, successful correctness trial only. `ignore/path.mbt:96` has six test-only references; `Ignore::path` has one test-only reference. Both live in product source behind `unused_value` suppression. | Move prefix removal into existing white-box test helpers and replace the one getter use with private-state access. The combined trial passed all correctness checks but changed rg's binary layout; its patch is retained and its source changes were reverted. Do not call it performance accepted. |

### Conditional candidates and rejected shortcuts

| Candidate | Evidence, decision and condition |
| --- | --- |
| C01: duplicated dump input loop | `hexdump/stream.mbt:75` and `od/stream.mbt:71` have the same 16-line read loop and similar skip/remaining/feed state. They have different rendering and numeric suffix dialects. Trial only the bounded input mechanism if it reduces total complexity; require short-read, offset, EOF, output-failure and both-command protection cases. No shared framework is justified merely by this text match. |
| C02: excess core exports / future-only async | Examples include `gzipops/cli.help`, internal helpers exported from netops, and `shell.Session::finish` retaining async solely for driver symmetry/future cleanup. Local consumers alone cannot prove a published API is unused externally. Review ownership and compatibility in a deliberate API change; these are not approved deletions. |
| C03: decision-document growth | ADR-0003 starts at 3,844 lines and interleaves current decisions with many dated experiments. Make current dispositions easy to locate and recover older full reports from their immutable Git revisions; do not rewrite failed measurements or promote historical candidates to acceptance. Avoid adding a second report hierarchy. |

The textual scan found only five equal-body groups under its conservative
function-body comparison. Other groups are weekday abbreviations, tiny whole-input
read helpers, two byte-count projections in searcher, and UTF-8 width arithmetic.
They are not five proven reasons for new packages. Parameter types, storage
ownership and dialects need separate verification; tiny duplication may be
cheaper than another public abstraction.

Retain the following checked boundaries:

- `core/bytesearch.count_byte(BytesView)` and SIMD `count(FixedArray, ...)`
  use different storage/load mechanisms; forcing a conversion would add copying.
- ByteMembership/ByteSetFinder already share the common membership operation.
  Keep their scalar tails and command-owned loading policies.
- `stream`, `tempio`, `fswalk`, `numfmt`, `time_zone`, `jq_filter` and
  checksum/gzip adapters have concrete consumers. Package reachability excludes
  valid test tools and the contracts catalog by design.
- Keep the two regex dialect families, literal/count/ordinary/span paths,
  bounded caches, fallback behavior, output no-replay states and temporary
  cleanup ownership. Their existence is not evidence of redundant algorithms.
- `StdoutWriter` translates errors and implements the printer protocol over
  BlockWriter; it is not equivalent to the empty upload forwarding function.
- Preserve Unicode/encoding data, fixed regression corpora, frozen published
  cases and explicit API-gap rejection tests. No uncovered branch was treated
  as proof of impossibility.

### Pilot evidence and next order

The retained code pilot changes only matcher source/interface and the four
indexing tests: 54 fewer source/test lines, plus two generated-interface lines.
Test-only helper relocation and blanket driver privatization are retained as
separate diagnostic patches, not applied changes. The first removal of
IgnoreMatch suppression correctly failed compilation. An artifact comparison
accidentally run after that failure examined stale artifacts; it is explicitly
named `invalid-stale-after-failed-build.json` and is not validation evidence.

The starting and final rg binaries have SHA-256
`132abfe2d9395c531210a583301dfc7fda124119cb4944f2de40634114a5f7a8`.
All 80 commands are compared as complete byte sequences, not just file sizes.
The broader helper-relocation trial had a different rg hash
`be78da8a48784b1c934289289ed8e56a68f8dceda1a03cd0107c061d203b79b8`;
it passed 1,706 Wasm tests and 2,117 functional checks with 19 platform skips,
but no timing acceptance is asserted for that discarded trial.

Final local validation on macOS completed on 2026-10-30:

| Check | Result and evidence under the directory above |
| --- | --- |
| Wasm interfaces, formatting, strict check and release build | Passed; `logs/final-info.log`, `final-fmt.log`, `final-check.log`, `final-build.log`. The only interface change removes matcher `replace`. |
| Complete Wasm tests | 1,706 passed, zero failed; `logs/final-tests.log`. |
| Native test-tool regressions | 118 passed, zero failed; `logs/tool-tests.log`. Native is used only for tools. |
| Final functional suite | 2,117 passed (2,064 contract and 53 boundary), 19 platform skips, zero failures; `final-functional/summary.jsonl`. |
| Final architecture inventory | 80 commands, 124 packages, 23 strategies, no failures; `final-architecture.json`. This clean-graph pass does not repair the A04 negative-control gap. |
| Complete command artifacts | 80 compared, zero changed; `final-artifacts.json`. |

Final functional stage durations in milliseconds are metadata 2,289,
compatibility 11,329, contracts 10,043, scenarios 25,757, policy 1,144 and
stress 7,529 (`final-functional/stages.json`). These are suite-stage
observations, not benchmark results. The toolchain is moon 0.1.20261023,
moonc v0.10.17+d971670cd and moonrun 0.1.20261023.

There is no claimed speedup, new platform acceptance, remote CI,
published-consumer result or GNU/Rust parity result. The reviewable code and
documentation remain uncommitted in the isolated checkout; the original
checkout remains clean at the starting revision.

Recommended order: resolve A03/A04 contract and guard gaps; keep the A01/A02
pilot as the smallest review unit; remove indexing-only state and empty
wrappers; then narrow the driver interface and test-only surface; investigate
IgnoreMatch/identity simplification only with their required correctness and
performance controls. Conditional duplication and document consolidation come
last. Each runtime-changing slice needs its own baseline, affected-workload
coverage and failure-preserving verdict before the next slice is combined.

## Further rg read and granular-output pilots (2026-10-29)

This follow-up starts from the preceding repair's default release Wasm
`32cf63b3fd8b0b4fd4caa35fd71933b70b547fdd6b9793dbc8f76742beb3f4c4`.
All 80 starting command artifacts and the complete dirty source were frozen
before editing. The 22 diagnostic cases are unchanged selections from the
89-task real-corpus matrix below, including stdin, early-exit file summaries,
counts, absent matches, ordinary output and match-only extraction. Each phase
uses two balanced windows with 12 measured rounds and complete Rust-oracle
stdout/status checks. The final candidate still requires the complete matrix
and all 156 shared protection profiles; diagnostics cannot replace either.

Adopted mechanisms:

- `FileReadBuffer` keeps physical file reads separate from the decoder's BOM
  and logical read requests. Each eligible worker reuses at most 1 MiB of
  storage. A file begins with 64 KiB physical refills; only a full block enables
  larger subsequent refills. Large logical requests bypass an empty cache.
  A short physical read is not EOF, and cached bytes precede a retained error.
  Stdin, preprocessors, non-regular files and explicit early exits retain their
  existing read path. This raises the private buffer bound by 960 KiB per
  eligible worker; it is not a bound on total search memory.
- The ordinary granular printer keeps match extraction, replacement and
  statistics. It shares the existing bounded plain-record admission helper
  with the buffered sink, avoiding asynchronous field/body/terminator calls
  when a complete record fits. Declining admission changes no output or
  counters. Color, hyperlinks, multiline formatting, over-limit records and
  explicit line buffering retain their existing ordered paths. No second
  output queue, pattern recognizer or corpus-dependent branch is introduced.

The reading mechanism follows the buffering principle documented by Rust's
[BufReader](https://doc.rust-lang.org/std/io/struct.BufReader.html). Fixed
64 KiB repeated buffering offered little benefit. Fixed 256 KiB buffering
reduced some large-file costs but added 3.08–3.42% to log status counting.
Fixed 1 MiB buffering regressed source literal/absent counts by about 7% and
was rejected. Progressive refills preserved the large-file benefit without
that regression: all 22 baseline/candidate pairs qualified, eight improved by
more than 5% in both windows, and none regressed by 3%. Wiki absent output
fell by 24.99–25.80%, log status output by 28.31–28.32%, and plain status output
by 29.39–29.53%. Source literal counts remained within -0.12% to +0.16%.

The separate granular-output phase also qualified all 22 pairs with no 3%
regression. Relative to progressive reads, log IPv4 match-only extraction
fell by 18.46–18.91%, and source definition extraction by 7.39–7.68%.

A third pilot used the digit-pair table principle from Rust
[itoa 1.0.18](https://docs.rs/itoa/1.0.18/src/itoa/lib.rs.html), retaining the
existing unsigned interpretation of all 64 bits. Boundary and varied-bit
correctness tests passed, but complete-command differences stayed within
±0.5% across the diagnostic set. It is not adopted: there is no
demonstrated application benefit to justify another formatting implementation.
Its source, tests, artifact and every timing sample remain in the pilot evidence.

The current public `moonbitlang/async@0.22.5` directory entry exposes `name`
and `is_dir`, not a complete kind; its identity field is private. The remaining
small-file gap therefore cannot be removed by assuming that every non-directory
is regular. A future pilot may overlap a bounded number of kind queries while
preserving traversal, link and error order, or use a released equivalent kind
observation. Neither a hypothetical improvement nor these I/O results establish
a language/compiler ceiling.

Pilot evidence: `/private/tmp/cmd-rg-batching-20261029-32cf63b3`.
The cumulative candidate is default Wasm SHA-256
`132abfe2d9395c531210a583301dfc7fda124119cb4944f2de40634114a5f7a8`,
1,992,455 bytes (1,036 bytes above the starting rg artifact). The other 79
command artifacts are byte-identical. Local checks pass 1,706 release-Wasm
tests, 118 tool regressions, 2,117 functional checks with 19 platform skips,
and architecture validation for 80 commands, 124 packages and 23 strategies.
The strengthened full-physical-refill decoding regression subsequently passed
with all 288 driver tests; rebuilding preserved the measured artifact exactly.

All 89 unchanged real-corpus tasks preserve complete output and exit status.
All starting/current pairs qualify; 34 improve by more than 5% in both windows.
The maximum observed loss is 0.686%, on `source-absent-lines`, and no task
reaches a 3% regression. Wiki absent output falls by 25.82–26.31%, log status
output by 27.93–28.07%, plain status output by 29.97–30.07%, IPv4 match-only
output by 21.18–21.40%, and source definition extraction by 7.43–7.49%.
Source literal counting remains effectively unchanged (-0.13% to +0.02%).

Current/upstream comparisons qualify 88/89 tasks. In this same run the number
more than 10% slower than upstream in both windows falls from 45 to 35; the
number more than 10% faster rises from 10 to 14. Source literal counting is
still 2.11–2.12 times upstream's elapsed time. Current/Rust comparisons qualify
87/89. Preserve observational marks for Rust `source-exception-count` and
`logs-requests-lines-plain`, and upstream `literature-literal-lines-stdin-plain`;
their unstable measurements cannot establish comparative speed claims.

Separate Darwin `time -l` observations cover numbered/plain log output,
source count/file summaries and IPv4 match-only output, with two reversed-order
pairs each. Observed current peak RSS is 34.59–39.39 MiB, with paired changes
from -0.97 to +1.86 MiB. These five profiles are resource observations, not a
total-memory bound or a three-platform resource claim.

The initial protection invocation failed before timing because its frozen
build-directory inventory included the shared `core` directory (81 entries).
The corrected 80-command inventory copies exactly the original frozen bytes;
the original inventory and setup failure remain unchanged. The ensuing full
156-profile run preserves all outputs/statuses but qualifies 155/156 timings.
Its byte-identical `ln-symbolic-validation` control has a first-window MAD of
11.51% on one side; the other 155 profiles are stable and below the slowdown
limit. This run is not an overall timing pass. A separate zero-delay A/A check
of ln, regex cold startup and rg counting passes the original two-window,
nine-pair stability criteria. One additional complete confirmation is
pre-registered without changing artifacts, cadence, selection or thresholds;
all earlier samples and its eventual verdict are retained.

That single complete confirmation passes all 156 profiles: both windows,
all stdout/status checks, stability and the 5% slowdown limit. No profile in
the confirmation reaches a 3% observed regression. This confirms the candidate
under the unchanged protocol; it does not erase the first run's unstable ln
control. The setup failure, first complete run, A/A control and confirmation
are separate evidence directories, with no sample filtering or further repeats.
Durable results, all 89 normalized rows, source snapshots, candidate/rejected
artifacts and raw observations are in
`/Users/winter/.codex/visualizations/2026/10/29/rg-batching-32cf63b3`.
These measurements establish local macOS default-Wasm acceptance and were
recorded before branch delivery. Remote CI, publication and exact-version
MoonX acceptance require separate evidence.

## General-corpus rg I/O repair (2026-10-29)

The unchanged enwik8, Shakespeare, NASA July 1995 log and CPython 3.13.0
Lib matrix exposed costs hidden by the earlier synthetic long-record emphasis.
Its 89 tasks remain the general comparison; long-record, collision and cache
pressure profiles remain separate stress controls. Neither a generated single
long line nor an aggregate speedup establishes general search performance.

The repair preserves default release Wasm, the public async runtime and the
existing regex algorithms. It applies three changes in diagnostic order:

1. Retain the public directory entry's `is_dir` observation. Query unknown
   kinds without following links; do not eagerly request size or canonical
   paths. Full metadata remains available to actual size, link and sort users.
   Unknown entries are never assumed to be regular files.
2. Assemble unstyled prefixes synchronously and use the shared writer's
   existing 64 KiB default. Its existing synchronous admission mechanism is
   exposed as `BlockWriter::try_write_slice`: acceptance owns the complete
   span, while a decline leaves output untouched. The searcher can deliver
   ordinary matches or existing coalesced spans until one needs asynchronous
   I/O. That pending event is delivered exactly once through the ordinary sink.
   A complete record copy is capped at 64 KiB; prefix-free complete spans use
   the source slice directly. First events, large records, styling, replacement,
   statistics, contexts and explicit line buffering preserve their required
   event/flush behavior. Failure and cancellation retain the shared no-replay
   state; this does not introduce another output queue.
3. Reuse one 64 KiB initial block per search worker for opened regular files.
   The adapter returns the original short BOM prefix and combines retained
   bytes with subsequent reads, preserving decoder request boundaries. EOF
   and errors are retained without replay. Stdin, preprocessors, non-regular
   handles and explicit early-exit/file-summary modes bypass read-ahead.
   This adds bounded physical read-ahead to full regular-file searches, not a
   total search-memory bound. Existing long-record buffers retain their own
   capacity policy.

The design follows the separation of scanning and output described in
[ripgrep's implementation article](https://burntsushi.net/ripgrep/), the
[Rust 15.2.0 directory walker](https://github.com/BurntSushi/ripgrep/blob/15.2.0/crates/ignore/src/walk.rs),
and its small synchronous
[counting writer](https://github.com/BurntSushi/ripgrep/blob/15.2.0/crates/printer/src/counter.rs).
The community port at `b998d487614d70c1131e8f95dc13dcc9d90c5698` retains
cheap directory kind observations and a synchronous WASI output chain. Its
product source is identical to the imported pin
`2727c25819b00ddd1a0e9b24f9cb683931d64edf`; only documentation/scripts differ.
The comparison builds its default Wasm and does not run its manual O3 script.
These references guide mechanisms, not corpus-specific branches or different
regex semantics.

Remaining directory cost includes a public-API query for each unknown kind.
The current runtime's directory entry exposes no complete kind or identity.
Remove that query only when a released public API supplies an equivalent
observation, or a separately tested traversal change preserves link handling,
filtering and error ordering. Synchronous upstream WASI and the public async
runtime have different I/O costs; do not label the residual gap a compiler
ceiling without further measurements.

Evidence starts from `ee3fc42e7d9a8782dac3a194d81b3ad56781db6f` and frozen
artifacts for all 80 commands. Each adopted phase retains two balanced windows
against its predecessor. The final matrix compares the cumulative candidate
with that starting artifact, community rg and pinned native Rust rg 15.2.0.
Every stdout/status comparison, unstable window and qualified loss is retained;
default Wasm, resource observations, three-platform CI and MoonX acceptance are
separate verdicts.

Local correctness passes 1,703 release-Wasm tests, 118 test-tool regressions,
2,117 functional checks (19 platform skips, zero failures), and the 80-command
architecture inventory with 23 registered strategies. Generated interfaces add
the shared writer admission method and private rg adapter capabilities; no CLI
option or support boundary changes. Only rg's command artifact differs from
the frozen baseline (1,978,821 to 1,991,419 bytes); the other 79 are identical.

The final 89-task matrix completes all 8,544 measured invocations, plus 1,424
warmups, with full stdout/status agreement. All 89 before/after pairs qualify;
49 improve by more than 5% in both windows, with no qualified loss reaching 3%.
The largest accepted small cost is `logs-images-count`, +2.90% in both
windows; `wiki-absent-lines-plain` costs +2.16–2.25%. Both are stable timing
observations, not discarded noise, and neither is offset against output gains.
Of 88 qualified candidate/community comparisons, 43 remain more than 10%
slower in both windows and ten are more than 10% faster. The same run places
the starting artifact above that slowdown threshold in 59 tasks. The remaining
community `literature-literal-count-stdin` arm is unstable and cannot qualify
a speed comparison. Rust-normalized ratios retain their own qualification.

Representative two-window elapsed times, in milliseconds:

| Real workload | Starting artifact | Candidate | Community rg |
| --- | ---: | ---: | ---: |
| NASA `/images/`, numbered lines | 1633.27–1633.40 | 393.09–396.43 | 365.97–372.93 |
| NASA `/images/`, plain lines | 600.47–601.94 | 290.11–291.42 | 265.30–266.75 |
| NASA IPv4, only matching | 1541.80–1547.01 | 1265.20–1265.98 | 921.89–927.93 |
| CPython literal count | 394.40–395.22 | 296.97–297.66 | 141.78–142.05 |
| CPython literal numbered lines | 404.12–404.36 | 263.42–264.74 | 155.57–155.65 |
| enwik8 absent literal, lines | 62.93–62.95 | 62.64–62.85 | 41.10–41.11 |

The five predecessor comparisons preserve metadata, prefix/buffer, buffered
match, initial-file and coalesced-span stages. All 13 before/after pairs in
each stage qualify without losses reaching 3%; one metadata-stage community
count arm is unstable and remains recorded. Coalesced-span submission improves
plain NASA output by a further 37.6–37.7%; initial-file buffering improves
CPython searches by 3.0–5.0%. These subset results do not replace the full
matrix. The source formatting pass changes the rg artifact identity; final
comparisons use the formatted artifact, subsequently verified byte-identical
after the added cancellation regression and final build.

Separate Darwin kernel peak-RSS observations cover numbered/plain NASA output,
CPython counting and directory listing, twice in reversed order. Paired deltas
range from -0.20 to +0.59 MiB, with candidate peaks of 35.06–38.86 MiB. These
are observations, not an allocation bound or cross-platform resource acceptance.
The complete protocol, per-file identities, phase artifacts and every raw
window are retained in the dated local `rg-io-repair-ee3fc42` evidence bundle.
No remote CI, publication or exact-version MoonX acceptance is claimed here.

The cumulative shared protection run passes all 156 workloads, both windows,
all output/status checks, stability qualification and the 5% slowdown boundary.
The only 3–5% observation is unchanged `ln-symbolic-validation`: +4.09% in the
first window and +2.02% in the second. Its artifacts are byte-identical, so this
is retained as a control observation rather than attributed to rg's source
change. No changed-rg protection workload incurs a qualified cost reaching 3%.
Fixture and real-corpus identities match before and after their respective runs.

The next input-side hypothesis is to separate physical regular-file read
batching from logical decoder/binary windows. Current bulk counts can request
256 KiB while ordinary output with default binary handling retains a 64 KiB
window. NASA status counting takes 68.74–68.82 ms versus community
55.84–55.98 ms, while plain status output takes 106.63–107.22 ms versus
60.65–60.89 ms. This difference motivates measuring read-call counts and a
bounded file-buffer pilot; it does not prove the whole gap is I/O. Any pilot
must retain decoder chunk boundaries, binary stopping, cancellation, read-error
ordering, explicit early exits and long-record controls, then repeat the full
real-corpus matrix. Do not simply enlarge every logical search window.
Granular `-o`/replacement/styled formatting is another separate workstream;
the current bounded admission callback deliberately does not bypass its match
and event semantics.

## Execution governance (2026-10-29)

The audit of `9dc42846c486697054fa13333ae65e03965a9c09` identified A01-A16.
Governance is delivered in three reviewable batches: resource/error boundaries
and regression gaps; selection policy, cache/replay state and registry ownership;
then duplicated mechanisms and inherited engine preparation costs. Completion
requires the exact final commit's three-platform CI and an independent review
with clean-copy acceptance. Historical timing failures below remain unchanged.

Batch 1 implements A01, A02 and A12, and starts A15 transition coverage. Regex
count probes and subsequent streaming reads use the nominal reader capacity,
even after an earlier input enlarged retained storage. Replayed ordinary reads
retain their separate 1 MiB cap; this is not a total retained-memory limit.
History regressions exercise both bulk and ordinary count sinks, decoded input,
EOF and replay. The tac spool scope closes files before removing its directory,
reports cleanup-only errors, preserves a primary error, and runs cleanup under
runtime cancellation. Private injected-operation tests cover all error pairs
and cancellation. The unused `WriteColor.is_synchronous` capability is removed;
the actively used searcher synchronous-match protocol is unchanged.

The trailing Boolean in `LineBuffer.fill` remains a type-checking requirement
of its current loop expression. Semantic grep/rg fallback engines remain
necessary. This batch neither changes algorithm profitability thresholds nor
asserts a new performance or published-consumer acceptance result.

Batch 1 validation passes 1,667 release-Wasm tests, the amended 289-test
driver/tac selection and the 80-command/124-package architecture inventory.
The two default-release protection windows complete all 154 profiles with
equivalent output/status; 145 qualify. The timing verdict remains false because
`ln-symbolic-validation`, `rg-null-long-output-8m`, `rev-long-8m`, all four tac
controls, `uniq-long-8m` and `paste-serial-8m` fail stability. No qualified row
exceeds the 5% slowdown boundary. Only rg and tac artifacts changed. Evidence:
`/private/tmp/cmd-governance-20261029-9dc4284/phase1-protection`. These preserved
windows do not qualify a whole-suite performance claim.

Batch 2 addresses A03-A08 and A16. Searcher-owned policy distinguishes streaming
discard eligibility, read capacity and sink delivery. `LineExecution` records
count/coalesced/synchronous/ordinary priority, while binary detection can
transition a coalesced plan back to its synchronous or ordinary route. Immutable
delimiter proof is computed once; content-dependent stopping remains dynamic.
`ReaderEntry` distinguishes a fresh search from a probe replay, with prefix
commit owned by the line buffer. Begin, EOF, read-error and sink-stop ordering
remain unchanged. Boolean preparation has uninitialized/declined/ready states;
literal plans make shift/AC ownership and resume handoff explicit. grep selects
its output/summary mode once and commits complete buffered records through one
accounting operation. Incremental cross-chunk reads and the two output queues
retain their different error contracts.

The owner-local policy inventory separates construction limits from measured
dispatch thresholds. Equal numeric values do not imply shared policy:

| Owner | Limit and unit | Kind / fallback | Evidence controls |
| --- | --- | --- | --- |
| rg driver | 4 KiB minimum block; 256 KiB ordinary block; 8 density samples in 4 KiB | Profitability; ordinary verifier or wide plan | boolean density, sparse and oversized boundary tests |
| rg driver | 4 KiB literal cursor | Retained-suffix bound; buffered matcher | literal long hit/miss and stream regressions |
| rg searcher | 64/256 KiB nominal reads; 1 MiB grown-record request cap | I/O policy; retained allocation is separate | reuse, bulk capacity, replay and EOF tests |
| rg automata | 512 NFA / 256 DFA states; 65,536 transition entries | Construction bounds; existing regex engine | NFA boundary and over-budget cached-decline tests |
| rg minimizer | 65,536 work components; 32 rounds | Construction bounds; original rows | exact work boundary, deep-chain and product-machine equivalence tests |
| rg wide scan | 64-byte probe; 32-byte sparse-exit threshold | Profitability; exact transition loop | frequent exits, stream phase and periodic controls |
| bytere literal set | 4,096 literal bytes; 1,024 AC states | Construction/packed-representation bounds; shift or ordinary matcher | byte/state N-1/N/N+1 tests and adaptive cache tests |
| bytere adaptive shift | 4 KiB density window; 256 verification checks | Profitability; bounded AC attempt | dense collision and sparse input histories |
| bytere record DFA | 256 NFA/DFA states; 8 skip plans; 256-byte acceleration entry | Construction/metadata bounds and profitability; span engine | exact 255/256/257 construction, exhausted-cache and certified-skip tests |

Schema 2 of the existing protection registry links strategy status, source,
named correctness tests and registered workloads. The existing architecture
runner validates those links, including rejection controls, on each CI host and
before performance windows. It does not replace semantic tests or reinterpret
historical timing failures as acceptance.

Batch 2's first frozen candidate passed semantic checks but regressed the
multi-literal grep count by 16.55% and 16.49% in stable windows. The boxed handoff
result is rejected. The revised handoff uses a value type and avoids rebuilding
an already cached shift plan. All 154 revised workloads preserve bytes/status;
132 qualify and no qualified row exceeds 5%. The whole timing verdict remains
false because 22 profiles are unstable. Retained small costs are
`rg-stream-frequent` 3.90-4.69%, `rg-min-broad-frequent` 3.62-4.08%,
`column-table-long-8m` 0.89-3.26%, `grep-set-short-64m` 0.54-4.49% and
`grep-hotspot-dense` -2.36% to +4.72%; commands without changed execution logic
remain controls, not attributed to this source change. Original and revised windows are under
`/private/tmp/cmd-governance-20261029-9dc4284/phase2-protection` and
`phase2-value-protection`. The first batch's three-platform functional failure
was the active tac help expectation missing its new cleanup sentence; batch 2
updates that current contract without rewriting frozen published expectations.
The revised batch passes 1,673 Wasm package tests and the complete local
functional suite, including the repaired tac help contract. The strategy
registry passes 18 bidirectional source-marker registrations and named-test
checks, including CRLF checkout controls. The multi-literal count ratios are
0.9884 and 0.9891 in the revised stable windows.

Batch 3 addresses A09-A11 and A13-A14, and closes A08/A15 evidence gaps. Wide
Boolean consumers share the four-byte transition and exact-exit probe operations;
endpoint replay, complete-record termination and cross-chunk state remain in
their specialized loops. The immutable `ByteMembership` shares nibble preparation
and the SIMD lane mask between `ByteSetFinder` and bytere's `RecordSkip`.
Loading fixed arrays or borrowed views, inverse membership and scalar tails
stay with those two actual consumers. This is the only new core public type;
it does not introduce a command-level framework.
Generated default Wasm retains a call to the shared membership mask; the source
`#inline` annotation is only an optimization hint, as specified by the
[MoonBit attribute documentation](https://docs.moonbitlang.com/en/stable/language/attributes.html#inline-attribute).
The mask performs no heap construction. Acceptance therefore uses measured
default-artifact protection rather than assuming the compiler removes the call.

Column uses one value-returning field-boundary scanner and one paged record retrieval operation.
Field-plan limits remain 64 KiB total, 128 rows and one eighth of each eligible
row's bytes, with a 1 KiB entry threshold and 12-byte entries. Exact boundary
tests cover the row threshold, per-row fraction and global remaining budget.
Display widths continue to be computed even when a partial plan is discarded.

Generic lazy DFAs now track constructed rows, searched offset progress and
pressure clears. After three clears, fewer than ten searched bytes per
constructed row retires that mutable engine for its remaining lifetime. A
productive window resets its accounting instead. Prefilter jumps count as
progress, conservatively favoring continued DFA use. Unicode quit does not
count as cache pressure. Forward and reverse retirement returns the existing
failure result and restarts the original full query through PikeVM; no partial
span is reused. Tests exercise real productive searches between pressure
windows, repeated retirement in both directions, and later ASCII queries after
Unicode exits. The thresholds are profitability policy, not language limits.

Both NFAs still compile eagerly: syntax/size errors, group names and error
timing remain constructor contracts. Only the non-raising PikeVM storage and
reverse DFA storage are prepared once on demand. The forward DFA remains the
shared search/Boolean-plan entry. Half searches can avoid reverse/capture storage;
captures and reverse-budget failures still prepare the complete fallback. The
separate empty-input profile observes construction including startup; dense
count, captures, replacement and pressure profiles observe repeated work.

The first batch-3 protection candidate is rejected: all 156 profiles preserve
output/status, but only 126 qualify (19 unstable and 11 stable rows beyond the
5% boundary). Stable generic-regex losses reach 38.61%; column table output
reaches 5.82%. The preserved `phase3-protection` windows remain failed evidence.
The revised DFA records progress through one `finish_search` operation at each
search exit, keeping the mutable cursor out of a deferred closure. Column's
shared scanner returns a value record with explicit presence; neither a
capturing field callback nor an optional boxed field result is retained. The
optional-result pilot regressed table output by 18.83% and is also rejected.
Nine-pair diagnostic measurements of the revised value result are +1.18% for
table output and -2.87% for long table rows; they are observations, not completed
two-window acceptance. The raw pilots and rejected artifacts remain in the
governance evidence directory.

The revised `phase3-value-protection` windows preserve all 156 outputs/statuses;
145 rows meet stability and 143 meet all timing rules. Eleven rows are unstable.
`rg-pilot-long-output-hit` is +5.035%/-1.784%, and the byte-identical `rev-8m`
control is +5.427%/-2.963%; both still fail the per-window slowdown rule. They
are not averaged into passing results. A further revision keeps the probe-entry
guard in each specialized wide loop and shares only actual exit probing, avoiding
unnecessary result transfers and stream-state writes on ineligible iterations.

The guarded `phase3-guard-protection` candidate completes both 156-profile windows
with equivalent bytes/status. Of 133 stable rows, 132 satisfy all timing rules;
no stable changed-command row exceeds 5%. The unchanged sort artifact's
`sort-n-8m` control is +0.61%/+6.83% and remains failed evidence, alongside 23
unstable profiles. The complete timing verdict is false. This control cannot
establish a source-induced slowdown, but its failure is neither removed nor
reclassified as a pass. Cumulative baseline protection is recorded separately.
Qualified small-cost controls in that candidate include `rg-growth32m`
3.55-4.42%, `rg-stream-long64` 3.40-4.12%, `rg-boolean-budget` 3.38-3.94%,
`rg-stream-phase-4095` 2.96-3.71% and `rg-min-constructor-chain` 3.50-3.76%.
These measured costs are retained explicitly; the complete per-profile values,
including unchanged-command controls, are in that directory's `summary.json`.
They remain separate from instability and resource observations.

The first cumulative comparison against the original `9dc4284` artifacts
preserves all 156 outputs/statuses, but only 127 rows satisfy all timing rules:
27 are unstable, and the stable `rg-growth8m` and `rg-growth32m` controls reach
5.14% and 5.82% in one window. The identical workloads also retain their
separately registered streaming controls; neither set of observations replaces
the other. `cumulative-protection` remains failed. A same-artifact A/A diagnostic
records ratios 0.9851 for rev, 0.9696 for rg output, 0.8955 for grep inverted
output and 0.9981 for rg 32 MiB growth; this exposes output noise but does not
waive the two stable growth failures. Disabling bookkeeping inlining produces
byte-identical Wasm and is not a fix. Restoring explicit four-transition groups
does not materially improve the diagnostic and is not retained.

The subsequent candidate retains both shared wide kernels and changes the
immutable membership pair from a reference object to a value type. Its public
method signatures and the two consumers' semantics are unchanged. Default-Wasm
diagnostics measure cumulative growth8/32/64 ratios 1.0225/1.0262/1.0271;
complete protection windows remain the acceptance evidence, not these probes.

The first value-membership full window (`phase3-final-protection`) terminates
with `No space left on device` while opening the paste output file. It has no
complete two-window verdict and is rejected as incomplete evidence. At the
user's request, historical temporary experiments are deleted directly, retaining
the current governance directory and the three recent search experiment groups.
Temporary usage falls from about 88 GiB to 24 GiB, with available disk space
increasing from 121 MiB to about 55 GiB. The candidate Wasm is unchanged across
cleanup. Any post-cleanup windows are separately identified environment trials;
they do not overwrite or qualify the earlier failed windows. Swap usage remains
about 1.7 GiB after disk cleanup, so disk space is not a claim of idle memory.

The post-cleanup `phase3-clean-protection` run preserves all 156 outputs/statuses;
154 rows are stable and 152 satisfy all timing rules. The value-membership
candidate is rejected: `rg-pilot-long-regex-64` consistently regresses by
63.22%/62.02%; the unchanged tac multi-file control also exceeds the boundary
in one window. Two other profiles are unstable. The representation change alone
is therefore insufficient. Each SIMD consumer now loads its immutable membership
value once before the scan loop. This retains the shared mask, specialized
loading/polarity/tails and the value representation without repeatedly obtaining
the same nested value for each block. The six-profile diagnostic against the
original baseline records long-regex64 at 0.9620, growth8/32/64 at
1.0225/1.0116/0.9981, grep-many at 0.9974 and grep-long-miss at 1.0061, with
equivalent outputs/statuses. These probes motivate the revised complete windows;
they do not replace them or establish the compiler-level cause conclusively.

The hoisted value candidate (`phase3-hoist-protection`) preserves all 156
outputs/statuses; 149 rows are stable and 148 qualify. It is also rejected:
`rg-boolean-false-positive` is +5.77%/+2.62%, while seven rows are unstable.
The next candidate retains the two loop-entry bindings but restores an immutable
reference representation for the shared membership pair. This changes no mask
operation, eligibility rule or public method signature. Nine cumulative
diagnostic profiles remain equivalent, with long-regex64 at 0.9534 and the
remaining ratios between 1.0036 and 1.0344. Representation choice is measured
against all registered controls rather than inferred from a narrow probe.

The final cumulative `cumulative-bound-protection` windows compare this candidate
directly with the original `9dc4284` artifacts. All 156 workloads preserve
output/status, and 154 satisfy every timing rule. No stable row exceeds 5%.
Only the byte-identical `ln-symbolic-validation` and `tree-directory` controls
fail stability, so the whole-suite timing verdict remains false. Their noise is
not reassigned to source changes or counted as a pass. The following qualified
3-5% costs are retained explicitly; all values are percent elapsed-time changes
in the first/second windows, separate from instability and resource observations:

| Cumulative control | First / second cost |
| --- | --- |
| `rg-stream-sparse` | +2.81% / +3.50% |
| `rg-stream-phase-16` | +4.23% / +3.59% |
| `rg-stream-phase-4095` | +3.44% / +3.51% |
| `rg-pilot-late-prefix-hit-output` | +3.56% / +2.62% |
| `rg-pilot-short-prefix-output` | +2.87% / +3.05% |
| `rg-pilot-long-color-hit` | +3.16% / +3.50% |
| `rg-min-dfa-long-text` | +3.18% / +1.91% |
| `rg-min-broad-sparse` | +2.99% / +4.28% |
| `rg-boolean-false-positive` | +2.29% / +3.33% |
| `rg-boolean-sparse` | +2.86% / +3.31% |
| `rg-boolean-budget` | +4.03% / +3.46% |
| `rg-boolean-long-miss` | +3.12% / +2.79% |

The separate final-batch `phase3-bound-protection` comparison against the exact
`3393528` artifacts preserves all 156 outputs/statuses, with 155 rows satisfying
every timing rule and no stable loss above 5%. The sole unstable profile is the
unchanged `ln-symbolic-validation` control; the whole-suite verdict remains
false. Qualified 3-5% costs in this comparison are `rg-stream-sparse`
2.88%/3.18%, `rg-stream-phase-16` 3.59%/2.85%, `rg-stream-phase-4095`
2.91%/3.65%, `rg-pilot-late-prefix-hit-count` 3.30%/1.93%,
`rg-min-broad-sparse` 2.93%/3.61%, `rg-boolean-sparse` 3.06%/2.62%,
`rg-boolean-budget` 3.50%/3.80% and `rg-growth8m` 2.43%/3.67%.
Both final comparisons freeze the same 80 candidate artifacts. All earlier
failed, unstable and incomplete windows retain their original verdicts.

Separate Darwin `/usr/bin/time -l` observations run three alternating pairs
after timing, checking complete output, stderr and exit status in every pair.
Median maximum RSS (original/final, MiB) is 27.42/27.45 for column table output,
45.70/48.08 for grep multi-literal count, 37.83/37.78 for rg cache pressure and
31.64/31.63 for empty-input regex construction. The grep observation retains an
approximately 2.38 MiB cost: baseline samples span 45.70-46.00 MiB and candidate
samples 47.45-48.36 MiB. No compiler or allocation cause is inferred from RSS
alone. The other three observations do not establish a meaningful memory
reduction, including for deferred engine storage. These four local process
observations are not Linux, three-platform or all-workload resource acceptance.
Raw records are in `final-resource-observations/observations.json` under the
governance evidence directory; cleanup/cancellation semantics remain covered by
the independent correctness tests.

The audit closure map is intentionally kept in this canonical ADR:

| Finding | Disposition | Required regression evidence |
| --- | --- | --- |
| A01 | Nominal count-probe/read capacity independent of retained allocation | bulk/ordinary reuse, decoded EOF and error histories |
| A02 | Exactly-once spool cleanup and primary-error precedence | all success/error pairs plus actual cancellation cleanup |
| A03 | Searcher policy with explicit line execution priority | count/coalesced/synchronous/ordinary, binary transition and stop controls |
| A04 | Fresh/replay entry and line-buffer-owned prefix commit | begin denial, complete-prefix error order, EOF and reuse |
| A05 | One explicit Boolean preparation lifecycle | lazy ready/declined state and repeated use |
| A06 | Valid literal engine plans and value-type handoff | lazy AC success/decline, dense/sparse reuse and stable count protection |
| A07 | Static grep execution mode and one buffered record commit | flag precedence, partial records, output failure and byte offsets |
| A08 | Owner-local limits with units and fallback | NFA/DFA/table/work/round boundaries, literal byte/state and field budgets |
| A09 | Shared transition/probe mechanisms, specialized outer loops | exact endpoint replay, all byte values, tails and chunk phases |
| A10 | Shared immutable byte membership | all singleton bytes, both polarities, offset views and scalar tails |
| A11 | Shared column field traversal and record retrieval | empty fields, escapes, page crossings, budget decline and output failure |
| A12 | Remove unused color capability | interfaces; active searcher synchronous protocol retained |
| A13 | Cost-based repeated-pressure retirement | productive/pressure histories, Unicode quits and forward/reverse fallback |
| A14 | Defer non-raising reverse/capture storage | compile limits, named groups, captures, exact literals and low-budget reuse |
| A15 | Explicit route and lifecycle observations | nominal literal reads, dense/sparse/dense choices and compact/wide selectors |
| A16 | Bidirectional strategy inventory in CI | sources, named tests, workload IDs, marker ownership and negative controls |

The registry documents 21 strategies and keeps rejected controls distinct from
adopted implementations. Static links do not prove a test enters its path;
the route observations above provide that separate evidence. Delivery requires
exact-commit CI, independent review and clean-copy acceptance;
timing, resource observations and publication remain separate verdicts.

Documentation profile update (2026-10-27): command READMEs describe invocation,
supported options and user-visible limitations; implementation details remain in
this ADR and the capability matrix. rg help now describes single-threaded reads,
unavailable mmap/PCRE2/device metadata and explicit terminal formatting rather
than inheriting upstream capability claims. Both version spellings identify
cli/rg. This changes documentation/metadata, not search support: rg remains an
unpublished candidate excluded from this release. Capability boundaries can
only be lifted with the public APIs and execution evidence specified below.

Delivery validation update (2026-10-26): [ADR-0001](0001-evidence.md) and the
[Wasm CI migration](../ci-wasm-migration.md) define current acceptance. Future
regressions and boundary unlock conditions below require Wasm on applicable
hosts and exact-version MoonX acceptance; Native command runs and backend
pairing are retired. Dated Native observations retain their historical scope.

## Target and decision

### rg bounded boolean count integration (2026-10-28, default release)

The count-only integration stage counts eligible records with a lazily prepared boolean DFA.
It needs neither match starts nor greedy endpoints. The command adapter owns
selection; regex construction and transitions stay inside `internal/regex`.
Mandatory-literal filtering remains active throughout each block, including
after a dense prefix. Exact literal and accelerated-prefix paths stay intact.
Assertions, empty matches, unsupported plans and construction-budget exhaustion
retain the existing engine. Preparation is capped at 512 NFA states, 256 DFA
states and 65,536 transition cells, with failed preparation cached.

The implementation is now selected only for blocks from 4 KiB through the
existing ordinary reader capacity of 256 KiB. Larger complete records use the
existing engine. This upper bound responds to a real default-release failure:
the first integration slowed general-regex long-record counts by 12-14%.
The prior extra `moon-wasm-opt -O3 -aimfs=20` experiment had hidden that loss.
That unrestricted integration is rejected and its two windows are retained.
The revised candidate restores the 8/20/32/64 MiB counts to ratios between
0.9972 and 1.0126. This is not a cross-block matcher or a bounded-record-memory
implementation.

All adoption measurements use plain `moon build --target wasm --release`,
without a manual optimizer pass, startup subtraction or timing observers.
The two complete-process protection windows report:

| Workload | Frozen baseline, ms | Candidate, ms | Observation |
| --- | ---: | ---: | --- |
| Regex count, 64 MiB | 309.07-313.97 | 104.88-105.55 | 66.1-66.4% less time |
| Unicode-class count | 65.79-66.48 | 44.39-44.81 | 32.5-32.6% less time |
| Frequent mandatory literal with no full match | 69.60-69.86 | 59.96-60.19 | 13.8% less time |
| Dense prefix followed by sparse tail | 30.85-30.94 | 31.59-31.89 | 2.38-3.05% more time |
| General-regex long-record count, 64 MiB | 787.20-797.43 | 796.30-797.61 | 0.02-1.16% more time |

The density-shift cost is retained as an explicit small tradeoff within the
registered 5% review boundary, not subtracted from other improvements. The
overall protection verdict remains **false**: 90/98 profiles qualify, including
43/44 rg profiles. The rg NUL-delimited long-output control is unstable, as are
seven unchanged-command controls (`ln-symbolic-validation`, `rev-long-8m`, four
tac controls and `uniq-8m`). No qualified profile exceeds 3.06% slowdown.
The noisy observations remain recorded, including unqualified slowdown values;
there was no unchanged-candidate rerun to obtain a passing gate.

The revised source passes strict Wasm checks, 1,642 Wasm tests and the
80-command/124-package architecture audit. The preceding integration passed
118 tool tests and 2,117 functional cases with 19 platform skips. The nine new
registered workloads cover density changes, literal false positives, Unicode,
assertions, budget rejection and long-record hit/miss fallbacks. The missing
prescribed architecture checker was restored from the preserved earlier tool.
All 80 artifacts at that stage matched its measured candidate; only rg changed.

Evidence is preserved in `/private/tmp/cmd-rg-count-adopt-20261028`, including
the pre-edit source and all 80 baseline artifacts, rejected `protection-count`,
revised `protection-guard`, and `guard-review.json`. This is local integration,
not a passing full performance gate, CI completion, upstream parity or release
acceptance. rg remains unpublished. MoonX has no optimization-level CLI option;
the installed tool executes cached registry Wasm via `moonrun`. A local release
build is not asserted byte-identical to a registry asset. Exact-version MoonX
acceptance remains a separate post-publication requirement.

The counting approach follows the distinction between boolean and positional
queries in [regex internals](https://burntsushi.net/regex-internals/) and retains
the mandatory filter described by
[regex-automata](https://docs.rs/regex-automata/latest/regex_automata/util/prefilter/index.html).
The remaining startup experiment uses first-access table construction, analogous
to [Rust LazyLock](https://doc.rust-lang.org/std/sync/struct.LazyLock.html), while
preserving every table value. Extra optimizer settings are excluded from the
delivery recommendation; [the Rust Performance Book](https://nnethercote.github.io/perf-book/inlining.html)
also emphasizes measuring inlining changes because they can cause slowdowns.

### rg lazy-table integration (2026-10-28, default release)

The final local candidate combines bounded boolean counting with first-use
construction of eleven Unicode tables and the default file-type table. Each
table is cached for the process after construction. Initialization contains no
async suspension, follows the existing single-threaded execution model, and
preserves every entry and its order. Encoding tables and Unicode meanings are
unchanged. The existing imports and public command interfaces are unchanged.

This is a source optimization. No manually optimized Wasm enters the final
comparison. It moves cold initialization behind the actual lookup, rather than
changing the optimizer level or dropping Unicode/file-type support. Generated
table entries must retain this initialization wrapper when regenerated.

The dedicated comparison uses default release Wasm, two windows, nine measured
samples per side and exact output/stderr/status checks. All 75 Wasm series
(25 workloads across original/count/combined) qualify. The two native Rust
output series are unstable, so their ratios are not accepted; 98/100 total
series qualify. The combined candidate's maximum window ratio to the original
Wasm is about 1.0101 (Unicode word-boundary fallback). Compared with count-only,
every combined window is lower, with a maximum ratio of 0.9943.

| Workload | Original release, ms | Count plus lazy tables, ms |
| --- | ---: | ---: |
| Empty stdin | 24.37-24.82 | 17.41-17.79 |
| Regex count, 64 MiB | 308.42-308.81 | 97.97-98.23 |
| Default fixed miss, 64 MiB | 50.06-50.32 | 43.18-43.24 |
| Unicode-class count | 66.15-66.18 | 38.01-38.15 |
| Frequent mandatory literal, no full match | 69.43-69.73 | 52.83-52.89 |
| File-type initialization and count | 32.85-32.93 | 28.25-28.41 |
| General-regex long output, 64 MiB | 794.89-800.15 | 769.29-778.95 |

The same raw comparison found a 5.34% first-window dense-output cost in the
count-only stage, with 0.14% in its second window. That extra finding is retained
alongside the earlier protection gate; it is not covered up by the count gains.
The combined candidate is faster than the original in both of those windows.
The qualified native regex-count reference takes 110.28-110.99 ms; the combined
candidate takes approximately 11% less time on this specific input. Other
qualified comparisons still show large gaps, including roughly 7.8-8.0x for
64 MiB general-regex output. This is not general native-Rust parity.

Validation includes 1,642 Wasm tests, 2,117 complete functional results (19
platform skips), 379 frozen-Wasm complete-process differential cases, and the
80-command/124-package architecture inventory. A temporary test module compares
all original table arrays against the lazy arrays, including nested aliases
and ordering; its 158 selected package tests pass. The integrated rg artifact
is byte-identical to the measured combined pilot.

Four separately observed Darwin kernel-RSS pairs show 7.36-7.81 MiB less peak
RSS than count-only. Regex-count peak RSS is 34,045,952 bytes and long-output
peak RSS is 165,380,096 bytes. These single pairs are local observations, not
a memory bound or formal cross-platform resource acceptance.

Evidence: `/private/tmp/cmd-rg-count-adopt-20261028/raw-study/`,
`raw-review.json`, `table-equivalence.log`, `combined-functional/` and
`lazy-guard-source.tar`. Extra O3/build-flag artifacts created before the delivery
constraint was clarified are retained as unused diagnostics; none is used in
these adoption results. The final full protection inventory additionally covers
standalone help/version and file-type listing/counting.

The final cumulative protection run is `protection-combined`: 92/102 profiles
qualify, including 47/48 rg profiles. The full gate remains **false**. The rg
NUL-delimited long-output control has excessive between-window drift on both
sides; its apparent speedup is unqualified. Nine byte-identical command controls
are also unstable: `ln-symbolic-validation`, `rev-long-8m`, four tac controls,
`column-table-long-8m`, `uniq-8m` and `uniq-long-8m`. Raw slowdown values in those
failed rows are retained, not treated as accepted costs. The largest qualified
slowdown anywhere in this run is 1.641%; there are no qualified 3-5% costs.
The final rg count is 97.80-98.23 ms versus 309.69-309.76 ms; empty input is
17.14-17.71 ms versus 23.72-24.81 ms; default fixed misses are 42.31-43.45 ms
versus 49.58-50.57 ms. Source/artifact coverage is complete for all 80 commands,
and only rg changes. This remains a local candidate, with no commit, push,
publication, three-platform development result or exact-version MoonX claim.

Further exploration should prioritize filter selection and long-record engines.
The existing `core/bytesearch/byte_set.mbt` already has an exact SIMD byte-set
finder, but the regex adapter classifies that prefilter as non-fast and may
prefer an inner literal. The frequent-`gamma`, absent-digit workload is a useful
test for a whole-block required-prefix rejection before per-record verification.
Retain dense-hit and changing-density controls so this does not discard the
new boolean-count benefit. For long records, separately investigate validated
transition-loop bounds and resumable boolean state; global O3/Oz substitution
does not satisfy the MoonX delivery requirement. These follow-up ideas have no
new measured speedup claim.

### Internal architecture consolidation (2026-10-28, local candidate)

The dependency direction is command adaptation -> domain implementation ->
runtime mechanisms and algorithms. Keep one `cli/core` registry module; source
API breaks are intentional and repository consumers migrate together. This
work does not change package versions, dependency versions, CLI semantics or
frozen published expectations. It is not a publication or platform acceptance.

The complete starting working tree, including untracked sources, is preserved
by `backup/core-restructure-20261027` at
`c7be0eb98222f6c3cd440cc8602fcc3c5e1f2c23`. The normal Git index was retained.
Eighty initial Wasm binaries, source archives, toolchain identities and each
independently reversible stage are under
`/private/tmp/cmd-core-restructure-20261027`. Observation-time source archives
must not be confused with the checkpoint source used to build a frozen binary;
phase evidence records both when they differ. Temporary evidence is local and
must be retained before deleting that directory.

Package decisions are based on consumers and behavior, not a line-reduction
quota. Moving code into another package is not a deletion. The inventory tool
`tests/architecture.mbtx` enumerates production/test dependencies, consumer
reachability and source/test lines for all 80 commands. It rejects cycles,
missing workspace imports and reverse dependencies into commands or tests.
That mechanical inventory complements, rather than replaces, the decisions
below and the compiler's import checks.
The complete tracked/untracked review counts 100,871 -> 100,395 implementation
lines and 33,694 -> 34,309 test lines in core/commands. This includes retained
generated data and excludes test tools and generated interfaces. The net
476-line implementation reduction does not count package/file moves as deletion.

| Core package | Decision and ownership | Consumers and constraints |
| --- | --- | --- |
| `cli` | Retain parsing; move capability/command records to `contracts`; remove the unused stdin-warning no-op. | Existing adapters retain option order, repeated-option precedence and diagnostics. |
| `contracts` | Own capability types and the command catalog; no runtime command policy. | The validation runner consumes the catalog. It need not be linked into command binaries. |
| `platform` | Remove test-only constant capability aliases and unused standard-stream forwarding APIs; synchronous capability queries stay synchronous. | Filesystem/process adapters retain explicit unsupported capabilities; no character-device heuristic substitutes for isatty. |
| `process` | Retain execution context, environment inheritance and launch/cancel policy; remove unused redirect/pipe forwarding functions. | env, find, make, xargs, timeout and shell retain their command-specific statuses. |
| `fsops` | Retain shared overwrite, backup, timestamp and traversal policy; do not collapse ordering-sensitive operations. | cp, mv, ln, rm, mkdir, ls, patch, test and other actual clients retain failure and cleanup precedence. |
| `fsops/mode` | Retain the shared octal parser. | chmod and mkdir use it; symbolic modes remain command-owned. |
| `fswalk` | Own directory-handle lifetime, entry kind observations and explicitly requested regular-file sizes. | rg, find, tree and grep share directory reads. `OpenFile` versus `ResolvedPath` preserves size-query behavior. Sorting, pruning, ignore rules and link policy remain callers' choices. |
| `stream` | Retain synchronous borrowed batches, owned scanner records and fixed output ownership. | Bulk consumers keep read sizes and specialized loops. The proposed enum replacement for output state was rejected after unqualified performance evidence; original partial-write/cancellation tests remain. |
| `tempio` | Retain exclusive temporary-directory creation, retryable failed cleanup and exact range copies. | sort, column and tac own their run/index/reverse formats and cleanup-error priority. |
| `bytesearch` | Retain SIMD fixed-array kernels and immutable-view SWAR operations. | rg, wc and stream use distinct storage forms; these are purposeful specializations. |
| `bytere` | Replace three optional-cache/boolean pairs with explicit uninitialized, ready and disabled states. | grep and other regex consumers keep syntax dialects, leftmost-longest/capture rules, bounded caches and whole-query fallback on exhaustion. |
| `checksum` | Own algorithms, digest specifications and incremental execution; private hasher implementation. | `checksum/cli` is the runtime consumer; no help, version or exit strategy in algorithm APIs. |
| `checksum/cli` | Own record formats, file handling, verification and command diagnostics; migrate existing format regressions. | cksum, md5sum, sha1sum, sha256sum and sha512sum import this adapter directly. |
| `gzipops` | Retain codec states, 32 KiB history and bounded Huffman tables; move command policy out. | `gzipops/cli` and codec tests retain level, CRC, concatenated-member, truncation and partial-output contracts. |
| `gzipops/cli` | Own options, help/version and command execution. | gzip, gunzip and zcat remain thin adapters with their existing behavior. |
| `shell` | Distinguish incomplete input from invalid syntax structurally; use one mutually exclusive loop-control state. | sh, make and split retain diagnostics, redirection order and scopes. Exit/return status and signal origin remain separate facts. |
| `netops` | Use `transfer` as the sole execution API; remove unused fetch types/wrappers; prepare header maps once and separate request, response, redirect and output responsibilities. | curl/wget profiles, authentication scope, cookies, timeouts and partial-response/file effects stay distinct. Deferred output and actual destination ownership are not duplicate layers. |
| `numfmt` | Retain explicit input profiles, normalized dyadic values, rounding and format stages. | printf, seq, od and hexdump need different widths and formatting rules; do not merge them into a lossy host-number conversion. |
| `time_zone` | Retain bounded TZif parsing and checked timestamp conversion. | date and diff retain 64-bit transitions, POSIX future rules and gap/fold rejection. |
| `jq_filter` | Retain the small public-AST adapter. | jq and jqlog require string-slice lowering; assignment paths must not be rewritten as ordinary values. |
| `quoting` | Retain byte-specific locale and shell escaping. | ls, cmp, split and printf have different quoting contracts. |
| `tabstops` | Retain parsed stops plus aligned/relative interval rules; add boundary/diagnostic regressions. | expand and unexpand share it, including overflow rejection. |

rg owns immutable search, input-selection and output plans constructed before
execution. Runtime statistics, buffers and adaptive caches are separate. Remove
the Standard/Summary printer builders and empty configuration-time statistics
copies, and construct their immutable values directly. The specialized matching
and output loops remain. The system adapter uses `fswalk` instead of a second
directory-entry wrapper whose optional kind was always absent.

An independently measured preparation change skips the default file-type table
when neither type changes nor type listing is requested. Explicit selection,
addition and clearing still build/validate the table before reading input.
The literal-count trial determines eligibility before discarding any input:
one nonempty literal up to 4096 bytes, a byte record delimiter absent from the
match, count-only sink, no context/inversion/early stop/multiline, no explicit
heap limit and no binary conversion/quit policy. It runs after the existing
decoder, retains at most literal-length minus one suffix bytes and ends an
unterminated record once at EOF. Complete short records retain batched scans.
Captures, assertions, regex alternatives and unbounded expressions stay on the
original path; this does not establish a resumable general DFA. Such a DFA must
prove both state continuation and recovery on cache exhaustion before it can
discard data. Earlier rejected general-DFA trials remain rejected.

The separate nl/paste/comm output trial reuses `stream.BlockWriter` at each
existing processing scope. Complete output is flushed on input failure and the
writer remains poisoned after partial write failure. Comm flushes before order
diagnostics. Numbering/section state, delimiter cycles, repeated stdin ownership
and sorted merge policy remain local; output buffering does not justify merging
their algorithms into one framework.

The rg regex compiler/automata, syntax, Unicode tables, ignore/glob frontends,
OS-string handling and decoding retain their separate semantics. Generated
Unicode data and the test corpus are not dead product code. Core BRE/ERE/Emacs
matching and rg leftmost-first matching are not interchangeable. Sharing a byte
kernel does not authorize changing either engine's selection rules. Removing
unconditional size queries from rg requires separate error-order evidence:
skipping a formerly observable realpath/file-size failure is a behavior change,
even when a successful traversal becomes faster.

The command review groups cover every module. "Retain" means its current
responsibility or specialization is justified; it is not an assertion that all
future performance work is finished.

| Commands | Decision and retained contract |
| --- | --- |
| rg | Restructure plans, printers and system adaptation; retain regex, Unicode, ignore and output semantics. |
| sort | Separate invocation/options, key preparation and comparison; retain packed keys, stable ties and spill formats. |
| find, grep, tree | Migrate directory mechanisms; preserve each traversal, pruning, output ordering and metadata-demand policy. |
| cksum, md5sum, sha1sum, sha256sum, sha512sum | Migrate to the checksum command adapter; algorithm state remains in the parent package. |
| gzip, gunzip, zcat | Migrate to the gzip command adapter; preserve codec levels and partial-output failures. |
| sh, make, split | Migrate through shell's typed parser/control state; retain command-specific orchestration and filter execution. |
| curl, wget | Use prepared transfer state; preserve profile-specific retries, output commit, authentication and cleanup. |
| column, cut, rev, tac, uniq, wc | Retain optimized batches, reverse blocks, field caches and fused scans; protect the earlier shared-foundation changes. |
| comm, nl, paste | Adopt shared output buffering only after behavior and timing checks; retain merge, numbering, section and delimiter state. |
| cat, head, tail, tee, join | Retain streaming/merge/follow and multi-destination policies; ownership differs enough to reject a universal command loop. |
| base32, base64, expand, unexpand, fmt, fold, tr, strings | Retain encoding, wrapping, whitespace and byte-translation rules; tab-stop sharing already has two consumers. |
| cmp, diff, patch, sed, csplit, expr | Retain comparison/patch state, regex dialects and address/capture semantics. Do not unify glob or regex frontends solely because their loops look alike. |
| chmod, mkdir, cp, mv, ln, rm, rmdir, unlink, touch, mktemp | Retain filesystem policy and explicit capability boundaries; use shared mode and operation mechanisms where semantics coincide. |
| ls, pwd, realpath, basename, dirname, which | Retain path representation, link, quoting and ordering behavior; display paths are not canonical filesystem identities. |
| date, printf, seq, od, hexdump, xxd | Retain precision, byte layouts, timestamp and formatting semantics; existing numfmt/time-zone ownership is explicit. |
| jq, jqlog | Retain distinct command adapters over the same AST translation; assignment paths remain protected. |
| env, xargs, timeout, printenv | Retain process/environment contracts and command-specific launch/status policies. |
| echo, true, false, yes, sleep, test | Retain concise dedicated implementations, short-circuiting and metadata behavior; a generic command framework would add no demonstrated reuse. |

#### rg search compilation ownership (2026-10-28)

Remove the command-local `grep_regex` package. Its only production consumer
was driver; printer and searcher imported it only for tests. Driver now owns
private `SearchMatcher` and `SearchPatternError` types and compiles search
policy directly from the execution plan. Case and boundary selection reuse
the existing enums. Delete the mutable builder, copied configuration,
configured-HIR wrapper and separate error-kind wrapper. Compiled matchers
retain the effective line terminator, regexes and excluded-byte set only.

Keep the existing regex dialect, Unicode, automata, candidate selection and
literal-count loops. Bounded inner-literal extraction now belongs to the HIR
in regex syntax, with its complete regression suite. It reuses the existing
literal poison predicate instead of keeping a second implementation. The
extra literal regex used for candidate lines is deliberately unchanged;
replacing it with a finder is a separate algorithm experiment, not part of
this ownership change. No new shared engine replaces `core/bytere`.

The old DFA byte-limit option was parsed but never consumed by the regex
compiler, which uses a fixed 10,000-state limit. Remove the dead copies in
search configuration while retaining argument parsing, diagnostics and the
existing execution behavior. This does not establish an effective byte limit
or a process-memory cap; wiring a real limit requires a separate behavior
decision and cache-exhaustion tests.

Move matcher-dependent printer/searcher pipelines to driver white-box tests,
preserving their expectations and injected sinks/clocks. Private searcher
capacity tests keep the existing test matcher. Do not expose the command
adapter or create a lower-layer dependency on driver to accommodate tests.
The removed package and all preceding local work are recoverable from
`backup/rg-boundary-20261028` (`c57c488`). Local artifacts and diagnostics are
under `/private/tmp/cmd-rg-boundary-20261028`.

Production MoonBit source decreases from 36,041 to 35,726 lines, a net removal
of 315 lines across rg after accounting for moved code. Test source changes
from 16,189 to 16,238 lines; every named test and its multiplicity is preserved.

The source passes 1,626 Wasm package tests, 118 test-tool tests and 2,109
functional cases with 19 platform skips and no failures. Another 268
pre-refactor/candidate Wasm comparisons preserve stdout, stderr and status
across patterns, case/boundary flags, CRLF/NUL, multiline, size options and
pattern-error precedence over missing input. All 80 command artifacts were
compared; 79 remain byte-identical. The rg binary changes from 1,956,396 to
1,950,003 bytes. The dependency audit passes for 80 commands and 125 packages.
The preceding-snapshot comparison ran all 71 registered workloads, each with
two windows of one warmup and nine alternating pairs. All 17 rg workloads
pass the unchanged dispersion, drift and 5% regression gates; their per-window
ratios range from 0.9815 to 1.0191. Across the full registry, 68 qualify and
three remain unstable: `ln-symbolic-validation`, `sha256sum-8m` and
`sha512sum-8m`. All three compare byte-identical binaries. The unchanged
`tac-long-8m` control records ratios 1.0215 and 1.0401; retain its small loss
separately, without attributing it to this source change. No qualified workload
regresses above 5%. The aggregate gate is not green, and no timing retry was
performed. These observations do not overwrite the earlier noisy windows.
An additional two-window comparison against the initial architecture baseline
qualifies all 17 rg workloads. The 64 MiB literal hit and miss ratios remain
0.6099-0.6141 and 0.5762-0.5796 respectively, preserving the earlier streaming
count gains. This cumulative comparison is distinct from the 71-row phase gate.

Nine separate Darwin kernel-RSS observations cover 8/20/32/64 MiB regex records
and literal miss records, plus a 64 MiB literal hit. All outputs/statuses agree
and temporary directories are empty after execution. The 64 MiB regex pair
records 165.656 -> 165.594 MiB; literal hit records 40.359 -> 40.328 MiB and
literal miss 40.266 -> 39.969 MiB. The largest observed RSS increase is
0.235 MiB on the 20/32 MiB regex rows. These are single resource pairs, not
memory stability qualification; sampled disk usage is a lower bound. None of
these checks establishes upstream parity or remote platform acceptance.

#### rg source footprint and resumable regex exploration (2026-10-28)

This is a temporary experiment, not an integrated implementation or a release.
The live product and test sources stay at the preceding ownership baseline.
`backup/rg-regex-explore-20261028` (`28ddcdc`) preserves tracked and untracked
source through a temporary index; all 80 release Wasm artifacts are frozen in
`/private/tmp/cmd-rg-regex-explore-20261028/baseline`. The normal index and
development HEAD are preserved. The same directory retains candidate sources,
compiler/test failures, raw timing windows, differential output and resources.

The current raw `.mbt` inventory, excluding `_test.mbt`, `_wbtest.mbt`, build
outputs and dependencies, is 89,272 lines under core and commands. Commands
alone contain 71,479 lines; rg contains 35,726: 40.02% of the first denominator
and 49.98% of the second. This intentionally includes data-bearing source and
100 lines in testdata packages, whose names alone do not mark them as tests.
Syntax, automata and Unicode account for 10,187 lines. Roughly 5,400 lines
across rg are Unicode/encoding tables, flag descriptions, type definitions,
escaping data and templates. Relocating these or moving a dialect into core
would not remove equivalent repository complexity. Remaining small wrappers,
unused fields and stale comments merit targeted cleanup; there is no evidence
for another large, semantics-preserving subsystem deletion. In particular,
the NFA `has_empty` field is always initialized to false and has no current
production reader; it cannot establish eligibility for a new streaming path.

The experiment targets `-a -c` searches with a byte record terminator, no
assertions or empty matches, and no multiline, inversion, context, early-stop,
heap-limit or detailed match-output requirements. DecodeReader remains ahead
of matching. Before discarding input, a separate boolean plan resolves every
reachable transition within 512 NFA states, 256 DFA states and 65,536 table
cells; failure declines the plan without changing the existing DFA cache.
An actual start-state end transition rejects empty matches. Chunk boundaries
preserve state; record completion performs one end transition and resets it.
The reader retains a fixed block instead of a complete record. These are
logical construction bounds, not process-memory caps. The experimental
closure interface is not a proposed shared public API.

The candidate history constrains the production design:

- V1 proves the streaming benefit but loses the existing fast prefix filter.
  Across 24 workloads, 22 qualify, one replacement-output control is unstable,
  and a sparse-prefix workload regresses 2.67-2.70x. It is rejected as a whole.
- V2 preserves fast prefixes and tries exact self-loop skipping inside the
  separate count path. Ordinary regex misses regress 29-31%; an additional
  random-text miss regresses about 2.85x. Its 24-row set also retains two
  unstable controls. This accelerator is rejected.
- V3 removes that accelerator. All 24 primary workloads qualify, but two of
  six held-out workloads regress: random misses by 41.9-42.0% and state churn
  by 5.27-5.39%. Driver diagnostics identify an existing inner-literal candidate
  filter on both expressions, absent on the structured long-record workload.
  Preserving only the prefix filter is therefore insufficient.
- V4 also declines streaming when driver already has an inner-literal
  candidate filter. Eligibility depends on compiled mechanisms, not named
  benchmark expressions. The existing generic DFA loop remains unchanged.

V4 passes all 24 primary protection workloads and five of six held-out
workloads. The remaining `rg-heldout-budget-short` row is unqualified: the
candidate's first-window MAD/median is 8.09%, with ratios 1.0514 and 0.9962.
Keep that failure; the aggregate gate is not green. None of the 29 qualified
workloads regresses above 5%. The empty-input row grows by 3.76-4.11%
(about 1.13-1.26 ms); it remains an explicit preparation-cost follow-up rather
than being offset against large-input gains.
The user accepted this specific 3.76-4.11% tradeoff on 2026-10-28. This does
not waive the unstable held-out row or authorize unrelated slowdowns. Further
size-driven rg decomposition is stopped; subsequent work targets measured
execution costs.

Qualified V4 observations against the frozen current Wasm baseline are:

| Workload | Baseline median, ms | Candidate median, ms | Speedup |
| --- | ---: | ---: | ---: |
| Structured regex miss, one 8 MiB record | 126.77-127.11 | 54.03-54.40 | 2.34-2.35x |
| Structured regex miss, one 20 MiB record | 272.30-272.55 | 83.90-84.16 | 3.24-3.25x |
| Structured regex miss, one 32 MiB record | 415.34-416.04 | 113.76-114.31 | 3.63-3.66x |
| Structured regex miss, one 64 MiB record | 798.62-799.69 | 192.62-193.05 | 4.14-4.15x |
| Ordinary regex line count, 64 MiB | 88.14-89.06 | 55.67-56.27 | 1.58x |
| Greedy positive count, one 64 MiB record | 978.19-982.58 | 40.56-41.06 | 23.9-24.1x |

The final row answers existence and avoids completing a greedy match; it does
not establish the same speedup for span, capture or output searches. The
fast-prefix long-record control remains about 794-798 ms and is not improved
by this conservative plan selection. Assertions and the default binary-policy
control also retain their original paths.

V4 passes `fmt`, `info`, strict Wasm check/build and 1,632 Wasm package tests,
including 191 eligible imported corpus cases consumed in 1/7/64-byte chunks.
Another 267 frozen-baseline comparisons preserve deterministic stdout, stderr
and status, including rejected expressions, error precedence, CRLF/NUL,
invalid UTF-8, mode exclusions and chunk seams. All 80 artifacts are compared;
the 79 other commands remain byte-identical. Nine separate Darwin kernel-RSS
pairs agree on outputs/statuses and leave no temporary entries. The regex
8/20/32/64 MiB pairs record 56.891/96.406/104.609/165.547 MiB in the baseline
and 40.000/40.047/40.063/40.156 MiB in V4. These single resource observations
demonstrate the retained-storage change, not statistical memory stability.
Literal-count controls retain their approximately 40 MiB process peaks.

Every timing window uses one warmup and nine alternating full-process Wasm
pairs, with two windows, MAD/median <=5% on both sides and median drift <=10%.
No startup subtraction, sample removal or timing retry is used. The held-out
fixture initially lacked its results directory and produced no measurements;
that setup failure is retained separately from the corrected first window.
No GNU/Rust ratio, MoonX release acceptance or remote-platform result follows
from these comparisons with the frozen current Wasm binary.

The executable next step is a count-only plan with an immutable transition
table and separate per-input state, preserving both kinds of existing
candidate filter. Reuse decoded record framing instead of keeping two similar
literal/regex reader loops. Preparation should be cached per compiled matcher;
consider delaying it until a long record is observed while the first block is
still retained. A subsequent experiment can resume prefix/candidate filtering
alongside the automaton to address dense-prefix long records; it must preserve
partial literals at chunk boundaries and cannot simply replace either filter
with scalar transitions. Extend binary policy, CRLF, assertions and capture-sensitive
modes separately, with fallback selected before discarded data would be
needed. The two regex dialects retain their frontends and selection semantics;
any shared continuation mechanism needs real consumers in both rg and grep.

#### rg upstream Wasm gap and baseline diagnosis (2026-10-28)

The separately collected comparison in
`/private/tmp/cmd-weekly-perf-20261028/summary.json` uses upstream rg.mbt
`b998d487614d70c1131e8f95dc13dcc9d90c5698`; its `.mbt` contents match the imported
`2727c258` revision. Both sides use the same compiler and moonrun and receive
`moon-wasm-opt --all-features -O3 -aimfs=20`. The current unoptimized artifact
has SHA-256 `2ef85099d6f4c16e8b9e4a60a9eb40e9641cb01693e332cd860dd3c6b36c26b1`,
identical to the frozen baseline of the resumable-regex experiment above.
These are complete Wasm processes, not Rust-native or MoonX measurements.

All seven comparable stdin workloads preserve output, diagnostics and status
and satisfy both nine-pair stability windows. Fixed counting improves
2.04-2.08x and regex counting is approximately unchanged. However, matching-line
output takes 3.10-3.15x upstream time; fixed misses cost 30-31% more, regex
misses 22-24% more, and collision/entropy misses about 26-27% more. These gaps
remain failures to preserve upstream performance; gains elsewhere do not
offset them. The absolute-file workload failed upstream WASI preopen access
and is excluded, not counted as a timing pass.

A new bridge comparison in `/private/tmp/cmd-rg-upstream-regression-20261028`
uses the frozen architecture-start artifact from
`backup/core-restructure-20261027` (`c7be0eb`) and the screenshot's current
artifact, with the same additional optimization and byte-identical input
fixtures. All seven workloads pass two windows of one warmup and nine
alternating pairs, including exact output/status checks. The 8 MiB output
medians are 144.66/144.12 ms at architecture start and 144.97/144.59 ms now:
0.21-0.33% slower. The four miss/collision controls are 2.0-3.3% faster now.
This locates the large gap before this architecture-reorganization baseline;
it does not identify the original introducing commit or attribute each cost.

Source comparison identifies a concrete investigation target: upstream's
search/printer chain is synchronous down to direct WASI reads/writes, while
the migrated implementation uses public async I/O and async callbacks through
the line printer. Both stdout buffers are 8 KiB, so a buffer-size difference
alone cannot explain the result. Async render/callback overhead is a
hypothesis, not a measured causal breakdown. Do not copy upstream FFI across
the repository's pure-MoonBit boundary or remove partial-write, cancellation
or output-order guarantees.

Next experiments should separate synchronous in-memory formatting from async
drains and measure ordinary output, colored/numbered output, context, replace
and only-matching controls. Separately diagnose preparation, read and candidate
costs in the miss workloads. Retain three explicit comparison identities:
the previous accepted artifact, architecture-start artifact and pinned
upstream MoonBit Wasm. Existing migration-relative protection cannot establish
upstream preservation. No product source, release artifact or manifest is
changed by this diagnosis; no new resource or remote-platform acceptance is
claimed.

#### Async output hot-path pilot (2026-10-28)

The isolated pilot is retained in `/private/tmp/cmd-rg-async-pilot-20261028`.
`backup/rg-async-pilot-20261028` (`495bb4b`) preserves the starting tracked and
untracked source without changing the normal index. The temporary source
reproduced all 80 starting Wasm artifacts before modification. Live product
sources and all 80 live artifacts remained unchanged at pilot completion;
`product-pilot.patch` passed `git apply --check` against that source.

The authorized follow-up adopted this exact patch. Evidence in
`/private/tmp/cmd-rg-output-followup-20261028/adoption.json` binds the local
integration to all 80 previously accepted artifacts, reproduced byte for byte.
Strict checks, 1,627 Wasm tests and 20 benchmark-tool tests pass again. The eight
additional rg profiles are now registered (79 total protection workloads).
`backup/rg-async-adopt-20261028` (`e0edbf7`) preserves tracked and untracked
source with a temporary Git index; the normal index and HEAD remain unchanged.
This adoption does not publish packages or establish new platform acceptance.

The selected implementation changes two production files and one test file.
rg skips the already-completed search prelude and an empty per-line prelude.
`BlockWriter` first attempts a synchronous private buffer append, entering the
existing async slow path only when needed. Shared append helpers avoid copying
the implementation into both paths. Public async interfaces, buffer sizes,
partial-write poisoning, cancellation and borrowing contracts remain intact;
both affected generated interfaces are byte-identical. No package, dependency
or runtime API replacement is involved.

The experiments distinguish three mechanisms. Extra printer inline hints do
not materially help. Skipping empty prefix work reduces ordinary output time
by about 23% without changing actual I/O. Separating the complete buffered fast
path adds gains in rg, nl, paste and comm. Merely extracting copy loops, or
removing the old async inline hints, does not reproduce those shared gains.
The deduplicated variant preserves the successful fast path. This supports a
local reduction in frequent async control-flow overhead, not a claim that all
async I/O should be replaced or that it explains every upstream gap.

The final ordinary release-Wasm comparison passes all 79 registered and added
workloads in two windows, each with one warmup and nine alternating pairs.
All output/status comparisons, both sides' MAD/median <=5%, and between-window
drift <=10% pass. No row is 3% slower in either window. All 80 artifacts are
compared: 17 change and have protection profiles; 63 remain byte-identical.

| Workload | Initial median, ms | Pilot median, ms | Time reduction |
| --- | ---: | ---: | ---: |
| rg matching-line output, 8 MiB | 168.47-168.72 | 121.95-122.56 | 27.4-27.6% |
| rg replacement output, 8 MiB | 306.38-307.04 | 248.34-248.61 | 18.9-19.0% |
| rg colored output, 1 MiB | 138.28-139.37 | 124.47-125.05 | 10.0-10.3% |
| nl, 8 MiB | 180.89-181.19 | 162.81-162.86 | 10.0-10.1% |
| paste parallel / serial, 8 MiB | 125.61-125.62 / 95.17-95.18 | 114.29-114.65 / 84.20-84.22 | 8.7-9.0% / 11.5% |
| comm ordered input | 182.51-183.41 | 165.33-165.43 | 9.4-9.8% |

Column table output does not benefit: it is 0.8-1.2% slower. Its shared writers
store snapshot data/indexes; table rendering already fills synchronous output
batches. Existing specialized loops in other commands are not rewritten merely
to use this mechanism.

Final validation passes strict Wasm check/build, `info`, `fmt`, 1,627 Wasm
tests, 118 tool tests and 2,109 functional cases with 19 platform skips.
Another 377 frozen-Wasm comparisons preserve prefixes, color, hyperlinks,
context, replacement, only-matching output, CRLF/NUL, invalid bytes, multiple
files and buffer seams. A new concatenation model checks partial writes,
capacities 0/1/2/8/16/17/32, line buffering and ownership after caller mutation.
Fourteen separate Darwin kernel-RSS pairs preserve outputs and leave no
temporary entries. The largest observed increase is 0.391 MiB; the 64 MiB
general-regex record remains about 166 MiB. Single resource pairs do not
establish memory stability or a process-memory limit.

A separate fresh comparison applies identical `-O3 -aimfs=20` optimization to
both sides and retains the pinned upstream Wasm artifact above. All seven
rows are stable. Matching-line output is 107.40-107.68 ms versus upstream's
47.14-47.65 ms, reducing the earlier 3.10-3.15x ratio to 2.26-2.28x. Fixed
counting remains about 2.03x faster than upstream. Fixed, regex, collision and
entropy misses still take about 22-30% more time; these are unresolved costs,
not improvements established by this output pilot.

An initial post-format identity check stopped before final measurement when
rg differed from its pre-format binary. Final evidence freezes and verifies
the formatted candidate. All trial sources, samples, failed identity checks,
resource diagnostics and final hashes are retained. The resource collector's
deprecated idempotent `ProcessInput.close` call is recorded separately; its
compiler warning does not originate in the product or strict product checks.
No integration, publication, remote CI or platform acceptance was claimed at
pilot completion; the later local adoption is recorded above.

#### rg output spans and input preparation (2026-10-28)

The follow-up evidence is in `/private/tmp/cmd-rg-output-followup-20261028`.
At this checkpoint the two previously accepted optimizations were integrated
locally. The new output-span implementation remained isolated in `pilot/`; the
reviewable
`output-spans-pilot.patch` applies to the live source. Only rg changes among
all 80 candidate artifacts. No development commit, push or publication occurs.

Three deliberately output-discarding diagnostic binaries isolate costs:
ordinary optimized output takes about 106 ms, discarding only sink writes
takes about 93 ms, discarding printer work takes about 63 ms, and synchronous
match callbacks without output take about 41 ms. These binaries are not
behaviorally equivalent and establish no accepted speedup. Their timings are
not an additive profile. They justify reducing per-line async dispatch rather
than replacing all async I/O. A direct printer shortcut improved ordinary
output by 12-13% but slowed context output by 5.35-5.57%; it was rejected.

The selected pilot instead reports adjacent matching lines from an already
validated reader buffer as one span. It never crosses a non-match gap or input
buffer boundary. A pending candidate avoids rescanning sparse matches. The
standard printer explicitly opts in only for plain block-buffered output;
line buffering, path prefixes, line numbers, context, statistics, replacement,
color granularity, trimming, column limits, multiline and early-stop modes
retain their existing paths. Binary detection disables coalescing before
delivering matches. Async entrypoints, read sizes and shared writer failure
handling remain unchanged. The internal Sink capability and Standard option
belong to their existing packages; no new core layer or FFI is introduced.

The final ordinary release-Wasm protection run compares all 80 artifacts and
81 workloads in two windows of one warmup plus nine alternating pairs.
Matching-line output improves from 120.25-120.86 ms to 48.18-48.58 ms, about
2.49x faster. Sparse output improves 7.9-9.1%; dense regex output improves
about 2.3x. All 27 rg workloads also pass a separate comparison against the
pre-async-pilot baseline; ordinary output there improves about 3.50x.

The full protection gate **does not pass**. Eighty workloads qualify, while
the unchanged `ln-symbolic-validation` reference has second-window MAD/median
5.81%, above the unchanged 5% limit. No workload exceeds the 5% slowdown
threshold. The unchanged `tac-long-8m` binary records +3.59% in the first
window and +0.51% in the second; that observation is not offset by rg gains.
All samples and both failures below remain retained without automatic retry.

The separate pinned-upstream comparison uses identical additional
`-O3 -aimfs=20` optimization. Ordinary output observes 49.56-51.51 ms against
51.51-52.04 ms, but the candidate's first-window MAD/median is 6.16%.
Consequently this is not a qualified parity claim. Nine other comparisons
qualify: dense regex output is about 6-7% faster, fixed counting is about
2.05x faster, and regex counting is within 1%. Default fixed, regex, collision
and entropy misses remain approximately 21-29% slower. These gaps are not
resolved by span output.

Strict Wasm check/build, info and fmt pass, as do 1,631 Wasm tests, 118 native
tool tests, 2,109 functional cases with 19 skips, and 377 exact frozen-Wasm
comparisons. Four new tests exercise fragmentation, gaps, CRLF/NUL, invalid
bytes, long records, binary stop prefixes, byte-budget partial-write failures,
cleanup without replay and a later read failure. Fourteen separate Darwin
kernel-RSS resource pairs have equal outputs/statuses and no residual entries.
Ordinary output's peak falls by 1.5 MiB; the largest observed increase is
0.266 MiB. The 64 MiB general-regex record still retains roughly 166 MiB.
Single resource pairs do not establish a memory limit or statistical resource
stability. The unchanged column control's disk sampler sees a transient 8 MiB
only on one side; the zero observation on the other side is a sampling lower
bound, not evidence that column stopped using temporary storage.

Further phase diagnostics separate argument parsing, plan construction, input
preparation, matcher/printer construction and scanning. Input preparation
costs roughly 9.4 ms locally versus 1.3 ms upstream even for empty stdin;
matcher construction is already faster locally. Source inspection shows that
the walker builds a global ignore matcher before returning explicit stdin,
although that stdin entry bypasses ignore filtering. Both sides' controlled
`--no-ignore-global` comparisons are stable: empty input falls from about
29.8 ms to 24.8 ms, collision misses from 30.0-30.3 ms to 25.5-25.7 ms, and
entropy misses from 31.7 ms to 27.3-27.6 ms. Their upstream gaps shrink to
about 5-7%; 64 MiB misses still take about 14% more time. This flag experiment
is diagnostic evidence, not an adopted default or a recommendation to disable
ignore rules globally. Internal clocks never subtract costs from complete
Wasm results, and no MoonX startup measurement is involved.

The next bounded preparation change should avoid loading global ignore data
when every explicit input is stdin, while retaining explicit ignore-file
diagnostics, type/glob validation, file-search rules and error ordering. It
needs dedicated configuration regressions before adoption. The span pilot
also remains pending its complete stability gates. Neither outcome authorizes
a broader architecture rewrite or establishes remote/platform acceptance.

#### rg span and stdin preparation adoption (2026-10-28)

The user approved local adoption of both bounded changes. Evidence is retained
in `/private/tmp/cmd-rg-spans-adopt-20261028`; local backup
`backup/rg-spans-adopt-20261028` (`7001dd1`) includes tracked and untracked
source without changing normal staged entries. The span path described above
is now integrated. A private ignore-builder argument also avoids loading global
Git ignore configuration when every walk root is stdin. Empty or mixed root
sets and filesystem walks keep the existing global matcher. The builder is
not mutated to disable ignore rules, and explicit ignore-file loading and
type/glob validation retain their earlier position and diagnostics.

Eight command regressions first checked the frozen preceding Wasm and now
protect stdin, mixed roots, file filtering, explicit opt-out, duplicate stdin,
missing explicit ignore files, invalid types and invalid globs. A walker test
also preserves explicit ignore errors and builder reuse. Existing span tests
cover fragmented input, gaps, binary prefixes, CRLF/NUL, invalid bytes, long
records, partial writes without replay and later read failures.

Only rg changes among 80 command artifacts. Strict Wasm check/build, info and
fmt pass, with 1,632 Wasm tests, 118 native tool tests, 2,117 functional passes
(19 platform skips) and 377 exact frozen-Wasm comparisons. The current checkout
lacks the architecture script referenced above; its retained verified copy
was run against the current tree from the evidence directory. That audit
passes all 80 commands and 124 packages, without restoring a repository file.

The preceding-source protection run retains 81 profiles and both complete
nine-pair windows. Ordinary output improves from 120.23-120.24 ms to
44.68-44.97 ms (2.67-2.69x), and empty stdin improves from 27.84-29.00 ms to
24.44-25.21 ms (12.2-13.1% less time). Both qualify. No qualified profile
regresses more than 5%, but the complete gate is **false**, with 73/81 profiles
qualifying. Failed profiles are `rg-output-dense-regex-8m`, `rev-long-8m`,
`tac-stream-8m`, `tac-file-8m`, `tac-long-8m`, `uniq-8m`, `cut-tiny-8m` and
`uniq-long-8m`. The rg candidate has second-window MAD/median 5.89% and median
drift 10.05%. The other seven commands are byte-identical; rev and cut also
have unqualified ratios above 1.05. Equal binaries do not turn unstable
measurements into passes or prove the cause of noise. No samples were dropped
and no unchanged comparison was retried to obtain a green verdict.

A separate required cumulative comparison against the pre-async-pilot source
qualifies all 27 rg profiles, with ordinary output 3.69-3.72x faster. It does
not replace the failed preceding-source gate. Fourteen separate Darwin kernel
RSS pairs preserve outputs/statuses and leave no temporary entries. Ordinary
output's observed peak decreases by 1.97 MiB; all measured rg peaks decrease.
The 64 MiB general-regex record still retains about 165 MiB, while literal
long-record cases at 8/20/32/64 MiB remain near 40 MiB. These are single paired
observations, not statistical memory limits. Disk sampling can miss transient
files, including the unchanged column control.

The requested chart uses only Wasm: current grep, current rg and pinned
upstream MoonBit rg `b998d487614d70c1131e8f95dc13dcc9d90c5698`. All three use
the same compiler/runtime and additional `-O3 -aimfs=20` optimization. Upstream
source, compiler versions, binary/fixture hashes, full samples and the chart
are bound in `comparison/`. GNU grep and Rust ripgrep native measurements are
excluded; this run has no verified Wasm builds for those two programs. Each
of 11 inputs has two windows with one warmup and nine alternating measurements
per tool. All 660 invocations agree on stdout, stderr and status; all 33
tool/workload series satisfy the unchanged dispersion/drift thresholds.

Optimized ordinary output takes 41.41-41.52 ms versus upstream 46.74-46.95 ms,
11-12% less time. Fixed counting is 2.23-2.26x faster; regex counting is within
1%. Dense regex output is 9-11% faster. Ordinary-output misses remain 45-48%
slower, sparse output 17-19% slower, entropy misses about 13% slower and byte
collisions 7% slower. The chart deliberately uses non-counting miss modes so
all three programs produce identical output; those ratios must not be
compared to earlier `-c` miss ratios as if the workload were unchanged. The
8 MiB general-regex long-record case is 4-6% slower. All timings include the
complete Wasm process, with no MoonX measurement or startup subtraction.

This integrates local source; it does not complete the full stability gate,
Linux/Windows development checks, actual-main validation or publication.
The earlier failed output/span/ln/tac observations remain immutable evidence.

#### rg text-output read batching (2026-10-28)

The user authorized adoption only after measured benefit and acceptable side
effects. Local backup `backup/rg-miss-pilot-20261028` (`d29cd36`) preserves the
preceding tracked and untracked source. Isolated sources, all 80 frozen command
artifacts, rejected candidates and complete measurements are retained in
`/private/tmp/cmd-rg-miss-pilot-20261028`.

Only `Searcher.reader_capacity` changes in product code. Plain block-buffered
output that already permits adjacent-match coalescing now starts with a
256 KiB input buffer when binary detection is disabled. This includes explicit
text mode and NUL-delimited records. Count-mode bulk scanning keeps its earlier
policy. Context, early exit, multiline, inverted matches, passthrough and
formatted/line-buffered output retain their existing eligibility guards.
Explicit heap limits still cap allocation; async entrypoints, the maximum
read request, growth policy and public interfaces remain unchanged.

Three isolated candidates establish the scope:

- Moving unmatched-buffer handling out of the async match/output functions
  qualifies all 20 selected controls, but ordinary fixed/regex misses improve
  less than 1%. That additional state handling is rejected for insufficient
  benefit; its source and measurements remain available in `s1-sync-miss/`.
- Text-output buffers of 128 KiB qualify seven controls and reduce fixed and
  regex miss time by about 15%. The selected 256 KiB candidate qualifies all
  20 controls and reduces those optimized-Wasm times by 20-21%. This supports
  reducing repeated buffer work, without attributing the entire gain to a
  particular async, copying or matching operation.
- Unconditionally enlarging the default binary-conversion path is rejected.
  A first `hit` line followed by 70,000 bytes and a NUL produces that line and
  a binary-match diagnostic in the frozen baseline, but only the diagnostic
  with the unsafe candidate. `unsafe-default/` retains both outputs and the
  failing Wasm. Default binary-detecting output keeps its original window.

Final release-Wasm measurements include the complete process and use two
windows, each with one warmup and nine alternating pairs. Median milliseconds
against the immediately preceding source are:

| Workload | Previous | Adopted | Time reduction |
| --- | ---: | ---: | ---: |
| Text fixed-string miss, 64 MiB | 49.02-49.56 | 38.15-38.67 | 22.0-22.2% |
| Text regex miss, 64 MiB | 51.29-52.11 | 40.30-40.86 | 21.4-21.6% |
| Text matching-line output, 8 MiB | 45.23-45.68 | 42.01-42.33 | 7.1-7.3% |
| Text sparse output, 8 MiB | 46.21-46.70 | 44.89-45.20 | 2.9-3.2% |
| Text dense regex output, 8 MiB | 54.35-54.78 | 51.29-51.49 | 5.6-6.0% |

The full registry grows from 81 to 89 profiles, including ordinary miss,
explicit text output and a long NUL-delimited record. All 35 rg profiles
qualify. Overall 88/89 profiles qualify, with no qualified slowdown above 3%.
The complete gate is still **false**: `tac-stream-8m` has second-window
candidate MAD/median 6.04%. Its command artifact is byte-identical; this does
not convert the unstable observation into a pass or establish its cause.
All samples and the failed verdict are preserved, without unchanged retries.

The separate cumulative comparison against the pre-async-pilot source also
qualifies all 35 rg profiles, with no slowdown above 3%. Ordinary output is
3.69-3.71x faster and text output 4.05-4.07x faster across those local changes.
This independent comparison does not replace the failed full-registry gate.

A separate text-empty control qualifies and changes by -0.2%/+0.5%. The
additional initial buffer capacity is 192 KiB, not a process-memory limit.
Twenty-two Darwin kernel RSS pairs preserve outputs/statuses and leave no
temporary entries. Text-output RSS increases are at most 0.30 MiB in these
single observations; text miss peaks decrease by about 1.1 MiB. The unchanged
64 MiB general-regex record still peaks near 165 MiB. Literal long records at
8/20/32/64 MiB remain resource controls. Disk sampling remains a lower bound;
these observations do not establish a statistical RSS limit.

The six text/NUL-output comparisons with pinned upstream MoonBit rg
`b998d487614d70c1131e8f95dc13dcc9d90c5698` all qualify. Both use the same
compiler/runtime and additional `--all-features -O3 -aimfs=20` optimization.
Text fixed/regex misses remain 13.7-15.3% slower than upstream; text matching
output uses 19.7-21.5% less time and dense regex output 16.0-16.4% less time.
Sparse text output remains about 13% slower. These text-mode rows do not
replace the preceding ordinary-mode chart. Default ordinary misses remain
unresolved; neither startup subtraction nor MoonX timing is used.

Five new regressions cover first hits after unmatched windows, exact prefixes
after partial writes, complete records before a read error, original binary
output prefixes and NUL-delimited gaps/final records. Validation passes strict
Wasm check/build, info/fmt, 1,637 Wasm tests, 118 native tool tests, 2,117
functional cases (19 platform skips), 377 frozen-artifact comparisons and the
retained 80-command/124-package architecture audit. Only rg changes among
the 80 command artifacts. No option, dependency, generated interface or
published record changes.

For default binary detection, the next candidate must separate physical read
batching from the original validation/output window, preserving the proven
binary prefix and failure boundaries before timing it. Scan fusion remains
unproven; it should not be introduced merely to compensate for an assumed
async cost. This is local source adoption, not full stability, three-platform
development, actual-main or published-consumer acceptance.


#### Local verification and remaining gates

The following records describe architecture stage 14, before the later rg test
and adapter consolidation above; they are preserved as checkpoint evidence.

The final source passes 1,670 Wasm unit tests and 118 Native test-tool tests.
Initial and candidate Wasm functional runs each report 2,065 passes, 19 explicit
skips and no failures. Strict Wasm check, release build, generated interfaces,
formatting and the 80-command/126-package dependency audit pass. Stage 14 has
identical command binaries to stage 13: its changes only add an explicit
heap-limit rejection regression and format the test tools. All 80 binaries
are compared with the starting snapshot; 22 change and 58 remain identical.

`final-protection` retains all 71 profiles, both nine-pair windows, one warmup
per window, raw stderr/status/output checks, fixture hashes and source binding.
Sixty-five profiles meet dispersion/drift and slowdown criteria. No qualified
profile exceeds 5% slowdown. `tac-file-8m` takes 3.17%/1.49% more time in the two
windows; its candidate and reference binaries are identical. This observation
is retained separately and is not offset against other gains.

The following six rows are **unqualified**, so the cumulative timing verdict
is false. Do not replace the run, relax thresholds or treat equal binaries as
a timing pass:

| Workload | Failed stability observation |
| --- | --- |
| ln-symbolic-validation | Reference first-window MAD/median 5.72%. |
| rev-long-8m | Candidate first-window MAD/median 8.96%; reference drift 12.50%. |
| tac-stream-8m | Candidate first-window MAD/median 11.41%. |
| tac-long-8m | Candidate second-window MAD/median 15.26%; reference MAD/median 11.64%/11.82%. |
| tac-multi-8m | Candidate/reference drift 14.40%/21.15%; reference second-window MAD/median 6.14%. |
| uniq-8m | Reference second-window MAD/median 5.57%. |

Rev, tac and uniq artifacts are byte-identical to their initial versions.
These observations alone do not establish a refactor-caused slowdown or prove
an external cause. The earlier `tac-long-8m` failure is still retained in the
foundation evidence. Stage 8's output-state enum candidate was independently
rejected after unstable rev measurements, then only that candidate was reverted.
Subsequent stages were rebuilt without it. Compilation/setup failures remain
in their original logs; correcting a harness issue does not erase them.

Stable cumulative improvements relative to this round's initial binaries:

| Workload | Candidate/reference time, two windows | Scope |
| --- | --- | --- |
| rg literal 64 MiB record, hit | 0.6101 / 0.6156 | Eligible count-only path. |
| rg literal 64 MiB record, miss | 0.5764 / 0.5832 | Eligible count-only path. |
| comm ordered | 0.0605 / 0.0612 | Existing merge with shared output buffering. |
| nl 8 MiB | 0.0575 / 0.0581 | Existing numbering with shared output buffering. |
| paste 8 MiB | 0.0594 / 0.0605 | Parallel output. |
| paste serial 8 MiB | 0.0456 / 0.0462 | Serial delimiter cycles. |

These are old/new Wasm ratios, not GNU/Rust ratios or speedups from the
project's first implementation. No fresh sealed upstream comparison ran in
this phase. Existing upstream gaps, especially general-regex long records,
remain open rather than being declared within the 3-5x target.

`resources-final` contains 16 Darwin kernel-peak observation pairs with equal
outputs/statuses and no residual temporary entries. Literal-miss peaks at
8/20/32/64 MiB are approximately 39.84/39.88/39.94/40.02 MiB, versus initial
56.94/95.92/104.44/165.44 MiB. The 64 MiB literal hit falls from 165.58 to
40.08 MiB. General-regex peaks remain 56.92/96.25/104.94/165.64 MiB, so neither
the automaton budget nor the literal fast path establishes a process-wide
memory ceiling. Comm rises from 32.28 to 35.98 MiB (+3.70 MiB, about 11.5%);
its output buffer is 64 KiB, so this single RSS observation must not be
attributed entirely to buffer size. Other observed positive deltas are at most
0.16 MiB. These single pairs do not establish statistical memory bounds.
Temporary allocated bytes are sampled at 100 ms plus observer execution;
zero sampled usage is not proof of zero transient disk use.
The separate `resources-spill` pair forces sort's one-MiB budget and an explicit
owned `-T` directory under the same 20-second deadline. Both runs finish with
identical output and zero residue; kernel peaks are 31.69/31.66 MiB. Sampled
temporary allocation reaches 11.86/17.68 MiB. Because these are asynchronous
lower-bound samples, their difference is not an exact peak-disk regression
measurement and does not establish a disk bound.

The final source remains local and uncommitted. Missing cumulative stability,
fresh upstream ratios, Linux/Windows development checks and actual-main
validation are explicit unfinished gates. Local functional evidence and
phase-level passes do not substitute for them. Retain the source/binary
checkpoints and raw evidence before cleaning the temporary lab.

Acceptance uses the unchanged per-workload thresholds in
[`PROTECTION.md`](../../tests/benchmark/PROTECTION.md). Every phase compares all
80 artifacts, even when timing only changed-command profiles. Final cumulative
comparison includes unchanged controls and the original baseline. Initial
test/setup failures and rejected candidates remain in evidence; they are not
silently replaced by later results. Three-platform development checks and
actual-main validation remain separate pending work until a later authorized
delivery workflow.

### Shared high-performance foundation (2026-10-27)

Updated: 2026-10-27. The user accepted the measured small abstraction costs in
the reader/kernel trials in exchange for a shared high-performance foundation.
The pre-integration source is preserved by local branch
`backup/shared-foundation-20261027` at `592311dfe2ed4b790ef2126a8e56a0a97094fe00`
(tree `a6ddac238c1f473592da61a164deb3a4eb344259`). This is local, unpublished work;
the earlier observations below retain their original sources and scope.

The adopted boundaries have actual consumers:

- Move rg byte kernels to `core/bytesearch`; rg imports them and wc's line-only
  path reuses the SIMD counter. Preserve wc's combined word/line loop and the
  immutable-view SWAR entrypoint. Moving code is consolidation, not deletion.
- Share record parsing through `RecordReader`; keep synchronous batch visits
  and an owned `LineScanner` facade with its existing 64 KiB read size. Never
  force bulk consumers through an asynchronous per-record interface. A retained
  view keeps its immutable backing block alive; long records remain unbounded.
- Put fixed-capacity output ownership in `stream.BlockWriter`, used by rg stdout
  and column snapshots. It rejects reentrant writes, consumes the pending queue
  before I/O and poisons the writer after failure/cancellation. Deferred flush
  cannot replay bytes. Command formatting and specialized output loops remain
  independent; borrowing requires the caller to keep storage unchanged until
  the awaited call completes.
- Put exclusive temporary-directory lifetime and exact positional range copies
  in `core/tempio`, used by tac, column and sort. Keep reverse scanning, column
  indexes/page caches and sort run formats separate. Close files first; each
  caller retains its explicit cleanup-error precedence. Abrupt process death
  still cannot guarantee cleanup.
- Construct rg path/JSON printer configurations once as immutable values,
  replacing their duplicate mutable builders. Larger matcher/searcher builders
  and the distinct rg/core regex semantics remain separate work.

The sort baseline timeout has a concrete repair: a 1 MiB budget previously
reserved 1.375 MiB for sixteen-way merging, leaving a one-byte run budget.
Choose fan-in and run storage together; at 1 MiB use two-way merging and a
512 KiB run budget. The default 64 MiB allocation remains unchanged. Tiny
budgets retain a minimum working-set fallback and oversized records are still
allowed. `--batch-size` is an upper bound, not a promise to allocate all lanes.
Neither accounting policy is a process-RSS cap.

Management rules live in the executable
[`protection.json`](../../tests/benchmark/protection.json) registry and
[`protect.mbtx`](../../tests/benchmark/protect.mbtx) runner. Every changed command
artifact needs an explicit profile; every profile needs complete output/status
and two nine-pair timing windows. Retain 5% per-window MAD and 10% between-window
drift limits. The accepted small slowdown allowance is separate from stability;
new losses above the 5% review boundary require diagnosis or revision. Timing,
resource observations, correctness and pinned-upstream compatibility remain
separate evidence. Never turn a missing profile, timeout or noisy window into a
pass. Extend the registry before changing another shared boundary.

The first combined output implementation failed six profiles despite stable
measurements: column's cache-cap case slowed about 17-18%, and rg color/only-match
output about 13-14%. Its complete windows are retained. Move in-flight state,
cancellation cleanup and rg error translation to the actual I/O boundary;
buffer filling remains synchronous, with bulk copying for larger byte views.
The ownership, partial-failure and cancellation regressions remain mandatory.
This avoids paying exception-cleanup work on every tiny formatting write.

Prior separate trials reported up to 3.36% slower tiny-record uniq and 3.32%
slower head-except-last; wc line counting improved 6.75-7.23%. Those numbers do
not establish the combined integration's result. The original `sort -S 1M`
8 MiB timeout remains a failed baseline case and requires a separate repair
observation with the original 20-second deadline.

Final local evidence is retained under
`/private/tmp/cmd-highperf-foundation-20261027`. Strict Wasm check/build,
1,652 release-Wasm tests and 2,065 functional cases pass, with 19 platform skips.
Sixty of 80 command binaries remain identical to the saved optimized baseline;
all twenty changed commands have registered workloads. All 51 profiles preserve
output, stderr and exit status in both nine-pair windows. Fifty qualify for
timing; their largest slowdown is 3.39%. Selected costs and gains are:

| Workload | First window time change | Second window time change |
| --- | ---: | ---: |
| wc line count, 64 MiB | -8.04% | -7.38% |
| rg color, 1 MiB | +1.10% | +0.71% |
| rg context, 8 MiB | -3.46% | -3.29% |
| column cache-cap, 8 MiB | +3.39% | +2.70% |
| uniq tiny records, 8 MiB | +2.30% | +3.08% |
| head except last, 8 MiB | +3.20% | +2.76% |

The final `tac-long-8m` reference has 7.79% second-window MAD and 10.08%
between-window drift; the candidate has 2.54% MAD and 3.44% drift. That profile
and the overall timing verdict remain unqualified. The identical tac binary
passed the preceding windows, but those observations do not replace this
failure. No sample was removed and no retry was made to obtain a pass.

Ten separate old/new Darwin kernel observations preserve output and leave no
temporary residue. The largest peak increase is cut long-record input at
1.05 MiB (3.62%); rg's single 64 MiB record remains about 166 MiB. These single
pairs are observations, not RSS stability qualification. The repaired
`sort -S 1M` 8 MiB case completes in 1.096 seconds under the original 20-second
deadline, matches default-budget baseline sort bytes and leaves no residue.
Its original same-budget timeout remains retained; no complete old/new speed
ratio is claimed. This is macOS local acceptance only, with one open timing
profile, no new GNU/Rust ratios and no cross-platform CI or publication.

Excluding test files and build/dependency caches, rg's implementation area has
962 fewer lines and all commands together have 1,001 fewer; core has 1,021 more.
The net implementation increase is 20 lines, including comments and blanks.
The main result is shared ownership and reduced adapter duplication, not a
claim that moving code to core deletes it. Further adoption must close or
explicitly retain the timing qualification gap and extend profiles when another
command starts using these interfaces.

### Long-record capacity and read requests (2026-10-27)

The next local continuation freezes the exact preceding SIMD candidate under
`/private/tmp/cmd-capacity-20261027`. Only rg changes among the eight observed
command binaries. Local main remains uncommitted; package versions, dependency
coordinates and published expectations are unchanged. The decision prioritizes
the largest gaps while retaining approximately 3-5x workloads as lower priority.

Line buffers previously added twice their capacity on exhaustion, producing
threefold growth, and requested all remaining space in each read. The selected
implementation doubles buffers below 1 MiB, grows larger buffers by one quarter,
and caps individual read requests at 1 MiB independently of capacity. Growth
remains geometric; configured allocation limits still cap additional capacity.
The existing allocation error at a full, unterminated record is preserved.
Complete records are still retained, so this is not bounded-memory matching.

The experiments separate capacity policy from read-request size. Simple
doubling reduced the 64 MiB peak but increased the 20 MiB peak substantially;
1.5x growth alone also retained an intermediate-size increase. Keeping the
original threefold growth and capping reads independently reduced the 20 MiB
peak from about 88 to 71 MiB and the 64 MiB peak from about 376 to 314 MiB.
This establishes an independent read-request contribution without attributing
all runtime memory to a particular allocator. All trial sources, binaries and
complete observations are retained, including rejected configurations.

All fifteen selected old/new workloads pass two nine-pair windows, with both-
side MAD/median <=5% and between-window drift/mean <=10%. Structured 8 MiB
input with 1 MiB records improves 1.13x (74.51/74.33 to 65.79/65.52 ms).
Single-record scan times remain near baseline; the 20 MiB probe is 0.8-2.2%
slower. Conventional counts, misses, output, collision and random-letter
controls retain their raw small changes. Full release Wasm execution is timed
through moonrun, including input, output and exit; no MoonX timing, startup
subtraction, dropped sample or retry for a passing window is used.

Ten separate old/new Darwin kernel pairs record the selected memory tradeoff:

| Input | Previous peak MiB | Selected peak MiB |
| --- | ---: | ---: |
| Single 8 MiB record | 76.45 | 56.92 |
| Single 20 MiB record | 88.30 | 97.22 |
| Single 32 MiB record | 161.27 | 105.00 |
| Single 64 MiB record | 375.63 | 165.78 |
| Unterminated 8 MiB record | 88.50 | 57.23 |

The 64 MiB reduction is about 56%; the intermediate 20 MiB increase is about
9 MiB. Ordinary count/miss peaks differ by less than 0.3 MiB. These are kernel
observations, not memory stability windows, and sampled RSS remains a lower
bound. The policy is selected for its large-record reduction rather than a
claim that every size improves. Further changes require multiple input sizes,
including non-powers of two, and ordinary throughput controls.

Six of ten fresh local Rust comparisons qualify. Terminated single-record
probes remain about 8.3-9.1x Rust time; literal and ordinary regex counts remain
about 3x. The unterminated, structured long-record, random-letter and collision
references fail dispersion or drift. Their complete observations remain
unqualified, without a retry or a claim that every workload is within 3-5x.
Two failed benchmark setup invocations are preserved separately; neither
produced a complete comparison window. No pinned Linux acceptance is claimed.

Strict Wasm check/build, 1,648 Wasm tests and 2,062 functional cases pass, with
19 platform skips. All 792 supplemental comparisons match the preceding Wasm:
384 repeated rg cases, 288 regex/set cases and 120 new long-record cases. The
latter cover stdin/files, CRLF, NUL records, BOMs, heap limits, anchors, counts,
offset output and unterminated records, and all agree with local Rust. The
existing repeated suite retains one pre-NUL output difference. Four additional
8/64 MiB held-out/single-record resource comparisons agree in bytes, status
and effects, with no timeout, stderr or temporary residue. The 118 unchanged
Native test-tool results are inherited from the preceding sealed round.
Final Wasm identities match the measured selected artifacts, and the other
seven observed commands remain byte-identical to this round's baseline.

A separate instrumented Wasm experiment retains five observations per entry:
the same artifact's early empty-operation entry takes 16.7-21.8 ms, ordinary
empty fixed search 29.8-30.3 ms, and empty regex search 31.5-32.2 ms. Coarse
in-command timestamps report 1-2 ms parsing, 2-3 ms argument preparation,
8-10 ms search setup/execution, about 2 ms building default file types, and
0-2 ms inside that search interval building the matcher. These diagnostic
intervals overlap and are not summed or subtracted from end-to-end timing.
They neither isolate runtime loading from global initialization nor establish
an accepted comparative speedup. Every instrumentation edit is restored.
File-type preparation alone is too small to be this round's main target.

The next architectural experiment should carry matcher state across chunks
for eligible line-count searches, allowing rejected long-record prefixes to
be discarded. Eligibility must exclude or explicitly preserve capture output,
look context, anchors, decoder boundaries, binary policy, heap limits and
fallback behavior; the current DFA API requires a complete haystack and an
end transition. Full-record retention remains until such a continuation
interface passes differential and resource checks. The existing general-DFA
self-loop trials remain rejected for ordinary-count regressions.

### SIMD candidate byte sets (2026-10-27)

After the user reprioritized approximately 3-5x workloads as acceptable for now,
the next local continuation targets rg's largest observed gap. Its baseline is
the preceding byte-field/count candidate, sealed under
`/private/tmp/cmd-pipeline-20261027` with 429 evidence hashes. New evidence lives
under `/private/tmp/cmd-prefilter-20261027`. All seven other observed command
binaries remain identical; only rg changes. Work stays uncommitted on local
main, without new versions, publication, push or remote workflows.

The bottleneck in the random-letter long-record probe was candidate lookup:
larger prefix-byte sets used scalar membership scanning before the DFA. A new
internal `ByteSetFinder` stores an immutable 256-entry membership copy and two
16-byte nibble tables. Sixteen input bytes are classified exactly at once, and
the first matching lane becomes the candidate. A scalar tail preserves the
bounded input window. It replaces only the larger single-byte-set and multi-
literal first-byte fallback scans. Existing one/two/three-byte, pair-set,
substring and Teddy paths keep their selection. Multi-literal candidates still
undergo complete literal verification in their original priority order.
This does not add checks or state expansion to the DFA loop. Internal prefilter
payload signatures change accordingly; the `is_fast` policy is unchanged.

Both nine-pair windows pass for all ten old/new workloads. The 8 MiB random-
letter long-record regex improves 1.70-1.72x, from 58.62/60.07 to 34.13/35.42 ms.
Conventional regex counts retain a 1.1-1.6% slower observation and literal counts
0.7-1.4%; other controls remain close to baseline. The selected tradeoff removes
a large scalar scan without the rejected general-DFA trial's 8-11% penalty.
Fresh fixed local Rust comparisons qualify eight of nine rows. The improved
long-record regex is about 10.6-10.7x Rust time, down from the preceding
17.3-17.6x observation, and remains a priority. Literal counts are approximately
3x and regular regex counts approximately 3.1x. The short collision case remains
13.4-13.6x. The random-letter literal reference fails its first-window dispersion
limit at 5.44%; its raw observations are retained without an accepted new ratio
or automatic retry. These local comparisons are not pinned Linux acceptance.

Two additional empty-input observations help locate the remaining cost. The
Wasm side is stable at 29.10/29.48 ms for fixed search and 30.47/30.61 ms for
regex search, close to the 31-35 ms light-input cases. The Rust reference fails
dispersion, so no comparative empty-input ratio is accepted. Empty-input wall
time includes runtime loading, initialization, command preparation and exit;
it does not identify which component dominates. Nothing is subtracted from
performance results, and MoonX is not involved. The next investigation should
separate these costs before changing the hot scan further, with particular
attention to eager command/matcher construction and Wasm artifact composition.

Strict Wasm checking/building and 1,646 Wasm tests pass. The complete functional
suite passes 2,062 cases with 19 platform skips. All 288 new regex/set comparisons
agree with both the preceding Wasm and fixed Rust executable, including high
bytes, long records, page seams, line anchors, folded classes and alternate
record options. The repeated 384-case rg set agrees with its Wasm baseline and
retains its single existing pre-NUL output difference. The previous 118 tool
tests remain recorded for unchanged tool implementations. Prior column/grep
correctness and resource results retain their scope and exact binary identities.

Four 8/64 MiB held-out/single-record regex resource comparisons match local Rust
in output, status and effects, without timeout, stderr or temporary residue.
Six ordinary old/new kernel RSS pairs stay around 40-43 MiB, with differences
below 0.3 MiB. A follow-up repeats the long-record observation against the exact
previous Wasm and measures both through Darwin kernel accounting: an 8 MiB
single record uses 79,839,232 bytes in both; a 64 MiB record uses 393,854,976 old
and 393,871,360 new bytes (about 376 MiB). The large peak predates this change.
All four kernel observations have the expected status, empty output and no
temporary residue. These are single observations, not memory stability windows.
`LineBuffer::ensure_capacity` currently adds twice the old capacity, producing
threefold growth and a full copy. Testing smaller geometric growth and then a
resumable long-record matcher is a concrete next memory direction; the observed
peak is not attributed entirely to that function without an allocation profile.

### Byte fields and fused count pipelines (2026-10-27)

The local continuation freezes the preceding block-count candidate in
`/private/tmp/cmd-pipeline-20261027`. Its eight baseline Wasm files match the
previous laboratory exactly. Work remains uncommitted on local main after
`987cf02`; versions, dependency coordinates and published expectations do not
change. Only grep, rg and column binaries change relative to this round's
baseline. The other five observed command binaries remain identical.

Rg's exact substring counter hoists needle offsets and SIMD pair setup outside
the repeated search loop. Each verified occurrence advances past its containing
record, retaining exact-literal and terminator eligibility. Grep's single-pattern
regex count path dispatches once per complete block through the new public
`bytere.RecordMatcher.count_records` method. The optional result contains matching
and complete record counts. Incomplete tails are excluded. Assertions, references,
unsupported programs or exhausted DFA state return None, and the caller runs the
ordinary matcher over the entire block before committing counts. Existing word,
whole-record, binary and long-record boundaries remain authoritative. The shared
core signature and rg's internal finder signature are regenerated explicitly.

Column tables borrow normalized byte fields instead of decoding snapshot rows
into strings and encoding each field again. Field splitting, display-width
collection and optional metadata construction share one ingestion pass. Only
rows of at least 1 KiB can cache field ranges and widths. The cache holds at most
128 rows and 64 KiB of encoded triples, with a per-row budget of one eighth of
the row length. Oversized partial plans are discarded while width collection
continues without restarting. No payload bytes are cached in this map and the
on-disk data/16-byte-index format is unchanged. The current row, global column
widths, cache object overhead, existing page caches and runtime memory remain
outside this metadata bound. Grid rendering retains its direct string-fetch
path; sharing the table's extra async wrapper had regressed its control case.

Final old/new measurements cover 27 workloads, each with two windows of one
warmup plus nine alternating pairs. All pass both-side 5% MAD/median and 10%
between-window drift limits. Full release-Wasm startup, input, output and exit
remain included; no MoonX timing or startup subtraction is used. Column's
8 MiB table improves 1.54x, long rows 1.47-1.49x, 1 MiB tables 1.35x and tiny
rows 1.11-1.12x. Cache-cap and dense-field probes improve 1.45-1.47x and
1.31-1.35x respectively. Grid time stays within 0.5% of baseline. Rg 64 MiB
literal counting improves 1.15x (62.50/63.35 to 54.16/54.95 ms). Grep's 64 MiB
regex count improves 1.09x (108.85/108.59 to 100.02/99.77 ms), with short regex
and structured/entropy rejection gains of about 4%. Dense grep literals and rg
fixed misses retain about 1% slower observations; other controls are near baseline.

All 17 fixed local GNU/Rust comparisons pass this round's two-window stability
criteria. Five workloads are within 3x in both windows, including grep regex
counts at 2.76x and rg regex counts at 2.97-2.98x. Rg literal counting is
approximately 3x. The user's updated prioritization accepts approximately 3-5x
for now and focuses subsequent work on the largest gaps; raw ratios and
stability thresholds remain unchanged. Rg misses remain 5.28-5.41x, its long structured DFA scan 5.50x,
and long random-letter DFA scan 17.34-17.59x. Small collision and random-letter
literal probes remain 10.90-13.06x. Grep fixed/dense/span paths remain 3.15-3.38x,
short random-letter regex rejection 7.81-8.15x and long random-letter rejection
3.64-3.68x. Prior noisy windows remain intact; this later local observation does
not retroactively qualify them or resolve hosted Linux variability. Column uses
the preceding Wasm artifact as its reference, not util-linux upstream acceptance.

Negative experiments are retained, not silently overwritten. Removing the first
column cache made its sparse large-row probe 2% slower but long rows 4% faster:
the failed-plan path was scanning twice. Combining required and optional work
resolved that overhead and produced the selected larger gains. An rg DFA trial
classified only already-resolved, nonaccepting self-loop bytes and cleared its
bounded plans with state identities. It passed differential unit tests and made
long records 1.26x faster, but ordinary regex counting regressed 8-11%. Checking
only after 256 consumed bytes and at 256-byte boundaries still regressed regex
counts 8-9% and lost the long-record gain. Both artifacts and all samples remain;
the complete trial, including its byte-set API, is removed from the candidate.

A temporary stage profiler confirms the default UTF-8 path already passes
through. In single diagnostic observations the binary pass took about 1.5-2 ms,
while the conventional regex matcher took about 270 ms. Read times varied from
about 9 to 25 ms. These instrumented component measurements do not explain all
wall time, certify repeatability or authorize subtracting initialization. The
profiler and dependency changes were restored before final acceptance.

Strict Wasm checking/building, 1,644 Wasm tests, 118 test-tool tests and 2,062
functional cases pass, with 19 platform skips. The five supplemental sets cover
1,728 cases: 1,698 equal their designated reference and 30 retain the documented
binary grep, overlapping tac and binary-output rg differences. The added 96
column cases cover cache thresholds, row limits, page seams, dense fields and
control/invalid bytes. Twelve resource comparisons agree in output, status and
effects, with no timeout, stderr or temporary residue. Column uses 1/8 MiB
inputs and the preceding Wasm reference; grep/rg use 8/64 MiB and local oracles.
Fourteen separate old/new kernel RSS pairs show about 23-43 MiB on the timing
workloads. Column's 8 MiB table observes 27.52 to 24.67 MiB; other differences
are small. These are individual observations, not repeated memory acceptance.
Sampled RSS still misses short rg runs, and the 64 MiB single-record grep probe
still samples about 226 MiB. Metadata limits do not bound whole-process memory.

The next deeper search experiment should first target the 17-18x random-letter
regex case and 11-13x collision/literal cases, with the 8x grep random-letter
case next. Approximately 3-5x workloads are lower priority. One candidate is
to dispatch an eligible long-record
executor before entering its hot loop, rather than adding per-byte planning
checks to the general DFA. It must preserve look context, end transitions,
cache-reset identities and scalar/PikeVM fallback, with ordinary short regex
controls and full Wasm measurements. Column can next test page-local field
iteration to reduce per-field objects without changing snapshot storage; the
retained cache ablation shows that a larger cache alone is not the main gain.
Grep literal/span output, tac stdin/dense-hit paths and wc metadata gaps remain
open. This local round does not resolve hosted Linux noise or establish new
three-platform, registry-consumer or pinned Linux upstream acceptance.

### Block counts and certified state skips (2026-10-27)

This round freezes the preceding candidate's source and eight exact Wasm
artifacts under `/private/tmp/cmd-block-20261027`. Work remains uncommitted on
local main after `987cf02`; no branch, push, registry upload or remote workflow
is part of this continuation. Published expectations and package versions stay
unchanged. The previous laboratories retain their complete dated evidence.

Rg's optional summary-count callback receives one count per complete reader
block instead of individual match events. It is selected only without context,
inversion, match limits, passthrough, multiline, stop-on-nonmatch or binary-quit
filtering. Existing sinks default to the ordinary event path. Confirmed matches
advance directly to the next terminator; candidate matches retain full-line
verification. Begin, binary notifications and finish keep their existing path.
Line-number bookkeeping is deferred to the existing block roll. Nullable and
assertion-bearing expressions retain normal discovery where required.

A second layer lets exact literal prefilters count matching lines inside the
finder loop. It does not turn a rejecting prefilter into an accepting matcher:
the expression must already be marked exact, and the configured terminator
must be absent from accepted matches. Substring search and terminator discovery
then run without constructing per-match metadata or crossing the matcher/sink
layers. Optional matcher/sink methods default to None; two helper signatures
are added within rg's internal regex packages. No public core signature changes.

Grep's assertion-free boolean DFA can build an exact self-loop membership set
for a state. Two 16-byte nibble tables represent all 256 input bytes without
hash collisions. Sixteen lanes are classified at once, and only the leading
bytes known to remain in the same nonaccepting state are skipped. Two bounded
64-bit loads construct the vector without copying or mutating the immutable
record. This uses the published experimental `moonbitlang/core/v128` surface,
already used by rg; the package opts into that alert explicitly. It adds no
FFI, native stub or host implementation. Cross-platform acceptance is pending.

At most eight state plans are attempted per DFA, with 256-element plan/attempt
tables and 32 bytes of SIMD membership payload per successful plan, plus runtime
object overhead. Existing 256-state/NFA limits remain. Resolving a row can fill
other bounded DFA entries; exhaustion declines acceleration and the existing
matcher fallback remains authoritative. Plans are keyed only by exact DFA
states, never by input hashes. Assertions, backreferences, word/whole-line
requirements, mandatory-literal filters and records shorter than 256 bytes keep
their prior paths. The scalar loop is separate to avoid accelerator bookkeeping
inside short scans. This is not a process-RSS cap.

Final local timing includes complete release-Wasm startup, input, output and
exit. Every window has one warmup plus nine alternating pairs, retaining the
5% MAD/median and 10% between-window drift thresholds. No MoonX timing, startup
subtraction, sample deletion or automatic retry is used. All 17 selected
old/new workloads pass both windows. Rg fixed counting improves 1.91-1.92x
(117.46/119.13 to 61.14/62.50 ms on 64 MiB); regex counting improves modestly.
Grep's long structured scan improves about 1.16x and long random-letter records
about 2.15x. Ordinary short structured/random scans are approximately unchanged.
The conventional grep regex-count control remains about 2% slower; this small
regression is retained rather than excluded. Other measured controls and
no-match paths remain in the complete result.

Fixed local GNU/Rust comparisons qualify 11 of 14 workloads. Rg fixed counts
are 3.39-3.42x Rust time, regex counts 3.03-3.09x, and misses 5.18-5.33x: none
of these is certified within the 1-3x target. Grep structured/long rejection
is 2.18-2.22x GNU time; long random records remain 3.59-3.66x. Fixed grep,
dense literal sets and span extraction remain about 3.26-3.43x. The ordinary
regex count straddles the boundary at 2.990/3.004x and is not rounded into a
pass. Short rg collision/entropy and grep entropy reference rows fail dispersion
and retain no accepted ratio. These macOS executable comparisons do not replace
the pinned Linux oracle profile or resolve hosted Linux stability failures.

The column pilot appends field ranges and display widths to each snapshot row,
then renders byte views without reparsing. Correctness tests pass and long rows
improve about 20%, but tiny rows regress 53-55%. Each row adds four bytes plus
twelve per field, explaining why small records pay disproportionate storage
and processing costs. Its 8 MiB table reference also fails dispersion. The
entire pilot is restored to this round's baseline; its source, binary and both
windows remain. The lesson is to test selective large-row metadata or a bounded
page-level cache rather than making every short record carry that format.

The first unrestricted grep skip pilot improves random short records but slows
ordinary structured and regex counting by about 17-18%. Separating mandatory
literal and short-record paths removes most of that cost. The intermediate
restricted variant still slows short entropy by about 4%; moving dispatch out
of the original scalar loop removes that measured penalty. All three artifacts
and their complete windows remain, and only the final artifact is selected.

Final strict Wasm checking/building, 1,640 Wasm tests, 118 Native test-tool tests
and 2,062 functional cases pass (19 platform skips). The four supplemental sets
cover 1,632 cases: 1,602 match their designated reference and 30 retain existing
differences, with no new regression. The 480-case grep extension agrees with
the preceding Wasm candidate in every case; its 27 GNU differences all involve
the two NUL-containing inputs, including inverted, nullable and whole-line
counts. For example, `grep -E -c -v '(ab|cd)+Z'` on sixteen repetitions of all
256 byte values returns 17 in both Wasm artifacts and 33 in GNU 3.12. The other
three differences are the previously recorded binary grep, overlapping tac
and binary-output rg cases. The 120 column cases compare against the preceding
candidate, not util-linux. These observations do not certify full upstream
compatibility. All case arguments, outputs, statuses and diagnostics remain.

Eight additional 8/64 MiB resource comparisons cover mixed record lengths with
NUL/high bytes and single long records. Output/status/effects agree with the
local oracles, with no timeout, stderr or temporary residue. Sampled RSS is a
lower bound: several rg samples capture only 192 KiB and cannot estimate its
actual peak. Eight separate old/new Darwin kernel pairs observe about 34-41 MiB
on the timed workloads, with each pair differing by less than 0.5 MiB. This is
single-observation evidence, not a memory-regression acceptance window. The
64 MiB single-record grep probe still samples about 226 MiB (GNU about 228 MiB);
long-record storage remains proportional to record length. Bounded DFA plans
do not bound input buffering or total runtime memory.

Next, rg's remaining count/miss gap calls for measuring reader/decoder/binary
passes as a combined block pipeline; a larger window alone is insufficient.
Grep's per-record boolean dispatch is a candidate for block-level count/reset
fusion, with exact separator and empty-match behavior preserved. Column needs
a hybrid metadata trial with explicit disk/RSS accounting and tiny-row controls.
The earlier tac stdin/dense-hit, grep literal/span and wc metadata limits remain
open; unchanged binaries do not acquire new performance acceptance here.

### Bounded ingestion and selective scan windows (2026-10-27)

This round starts from the previously validated local continuation, with its
eight Wasm artifacts checked byte-for-byte before implementation. It remains
uncommitted development on local main; versions, module manifests and frozen
release expectations are unchanged. Evidence is retained separately under
`/private/tmp/cmd-deeper-20261027`, including rejected sources and measurements.

Column ingests immutable record batches up to 1 MiB and stages data and 16-byte
index entries synchronously. Separate 64 KiB buffers bound pending data/index
writes. An encoded record that does not fit is retained once and written after
the pending data, without growing the batch. A record can still be as large as
the longest input record; this is not a constant process-memory bound. Global
widths, the complete disk snapshot, C-byte conversion, empty/NUL handling and
late-input-error behavior are preserved. Overflow is rejected before mutating
the pending buffers; a failed snapshot write aborts layout without replay.

Rg summary sinks can opt in to a 256 KiB initial reader window for full-input
line counts without statistics. The default sink method returns false. The
searcher additionally excludes match limits, inversion, context, passthrough,
stop-on-nonmatch, multiline and binary-quit modes; explicit heap limits still
cap allocation. Reusing a searcher with another sink restores the original
window. Slice/multiline binary sniffing keeps its original 64 KiB boundary.
This avoids a global constant change that would alter early-read behavior.
Eligible reader buffers add up to 192 KiB before long-line growth, with normal
allocator/runtime overhead and transient construction storage outside that
algorithmic difference. This opt-in does not promise the original ordering of
binary notifications relative to intermediate callbacks; the selected summary
sink exposes only its final count and does not stop on those notifications.

Tac uses the existing KMP state to certify a skip: only with no partial prefix
can a byte other than the separator's last byte be skipped during reverse
search. Public byte-view reverse search finds the next possible start. Partial
prefixes retain ordinary KMP transitions across reads; matching remains exact
and nonoverlapping, without a speculative cache. Tests cover sparse/dense data,
overlap, 33-byte blocks and 64 KiB seams in addition to the earlier exhaustive
short-input and long-separator comparisons.

All performance measurements include complete release-Wasm initialization,
input, output and exit. Two windows each retain one warmup plus nine alternating
pairs, with both-side MAD/median <=5% and median drift/mean <=10%. No MoonX timing,
startup subtraction, sample deletion or automatic retry is used.

| Workload | Speedup over this round's baseline | Qualification |
| --- | ---: | --- |
| column tiny rows, 1 MiB | 2.31x | both windows pass |
| column table, 8 MiB | 1.17x | both windows pass |
| column grid, 1 MiB | 1.23x | both windows pass |
| column long rows, 8 MiB | 1.10-1.11x | both windows pass |
| column table, 1 MiB | no accepted gain | baseline dispersion/drift fails |
| rg fixed count, 64 MiB | 1.08x | both windows pass |
| rg fixed/regex miss, 64 MiB | 1.24-1.26x | both windows pass |
| rg regex count, 64 MiB | 1.02-1.03x | both windows pass |
| tac multi-byte hit/before, 8 MiB | 1.12-1.13x | both windows pass |
| tac multi-byte miss, 8 MiB | 1.63-1.64x | both windows pass |

The 12-row combined comparison is stable, including controls. Tac's long-prefix
overlap control regresses about 1.8%; the unchanged single-byte file path varies
from 0.6% to 4.6% slower. Rg ordinary output is about 0.5% slower, the repeated
byte collision about 0.2%, and high-entropy miss improves 3.5-4%. These controls
are retained, not excluded from the result. The separate column phase has four
qualified rows out of five; its noisy 1 MiB row is not retried.

Fixed local GNU/Rust comparisons qualify 9/12 workloads. Tac file reversal is
2.73-2.76x GNU time and multi-byte miss is 2.60-2.61x, within target. Stdin stays
3.55-3.82x and multi-byte hit/before 3.95-4.01x. Rg fixed count is 6.51-6.53x,
fixed/regex miss 5.22-5.29x, and regex count 3.14-3.18x. The short tac overlap,
rg collision and rg entropy references fail dispersion and have no accepted
ratio. Column has no suitable local util-linux oracle. These macOS executable
observations are not pinned Linux or three-platform acceptance.

Strict Wasm checking/building and all 1,634 Wasm package tests pass, together
with 118 Native test-tool tests and 2,062 functional checks (19 platform skips).
The 432-case imported and 336-case layout differentials retain their two
previously recorded GNU differences. All 384 new rg stdin/file/directory cases
agree with this round's baseline; 383 also agree with Rust. The remaining case
uses `-n -b -o hit -`, 13,000 `hit a\n` records, then `tail\0hit\n`, 35,000
`miss\n` records and final `hit`. Both versions report NUL at byte 78,004, but
Wasm prints 10,922 preceding matches while Rust prints 12,287. This pre-existing
binary output/read-window difference remains unsupported parity, not a new
count-path regression. No existing difference is converted into acceptance.

Thirteen resource comparisons cover held-out binary/mixed-width inputs, long
records and 64 MiB tac/rg inputs. Output/status/effects agree with the round
baseline for column and fixed local GNU/Rust for tac/rg; stderr, timeouts and
temporary residue are empty. Ten paired Darwin kernel observations show
column peaks rising by 2.0-3.0 MiB, tac remaining approximately unchanged, and
rg varying downward by 0.6-1.9 MiB. These are one-shot process observations,
not memory guarantees; sampled RSS remains a lower bound. The audit checks
complete windows and exact final binary fingerprints. The earlier Linux
stability blocker is unresolved, and no remote CI or published acceptance ran.

The rejected rg short-needle standard-library-search pilot passes correctness
but slows misses about 5% and repeated-byte collisions about 39%; the existing
rare-byte pair finder is retained. A global 256 KiB reader probe established the
I/O batching benefit, but only the restricted summary opt-in is selected. The
old DFA block-cache pilots remain excluded. Further work should move rg count
discovery and newline aggregation into block-level operations; larger reads
alone leave the fixed-count gap above 6x. Column's next measured alternative is
recording field/width metadata during ingestion versus its extra disk/index
cost. Tac can investigate block-local output copying for dense hits; its sparse
skip cannot reduce that cost. Grep needs state-certified skips with entropy
controls, and wc's descriptor metadata API gap remains open.

### Local continuation after the documentation release (2026-10-27)

The maintainer authorized development directly on local main after the
documentation release. The merged remote release branch was deleted after
checking its exact head and ancestry, and local main fast-forwarded to
`987cf02`. The isolated candidate was then applied, adapting its README notes
to the new concise template and retaining all accepted coordinates, version
output, published expectations and release history. No new branch, publication
or main push is part of this continuation.

Tac now scans each block's multi-byte separator matches synchronously using the
existing reverse KMP failure function. An incomplete prefix carries between
backward reads. Completed nonoverlapping starts are retained in a reusable
array bounded by the block size. Ranges whose endpoints span later blocks use
the original positional copy; only fully contained ranges enter the output
batch. This matters when a separator is itself longer than a block or ends in
a later block. Input spooling, 64-bit offsets, before-separator semantics and
the regex path remain unchanged. Independent rightmost-substring tests cover
exhaustive short inputs, overlapping patterns and separators through 131,074
bytes, including one-byte reads.

Column's table renderer runs synchronously while required index/data pages are
cached and resumes async work only on a page miss or a full 64 KiB output batch.
An explicit field/padding/separator/newline cursor resumes inside expanded
rows, including inside UTF-8 output-separator bytes. It never materializes a
complete padded row. The full input snapshot, 16-byte record index, bounded page
caches and longest-record/field storage are unchanged; no input is reopened.
The renderer adds one bounded output batch and current-row state. Output errors
stop without replaying buffered data; completed input records remain available
after a late input error.

Column also classifies ASCII separators once per snapshot and reuses the table
for width calculation and rendering. Input conversion checks eight bytes at a
time and decodes a proven ASCII prefix in bulk. NUL truncation, blank-line
filtering, high-byte `\xHH` escapes and the C-locale control/color width rules
retain their previous behavior. The public rejection of non-ASCII input
separators is unchanged. Grid rendering keeps its previous layout path and
benefits only from the shared input conversion.

Local evidence is retained under `/private/tmp/cmd-local-20261027`: the released
source, the imported candidate before further changes, each measured pilot,
two complete nine-pair windows, and separate correctness/resource observations.
Direct-Wasm timing and existing stability thresholds are unchanged. The
initial table-batch pilot's small grid slowdown remains visible; subsequent
conversion changes are evaluated as a new artifact, not as a retry of that run.
The earlier rejected DFA block cache remains excluded.

Final local observations compare against the imported candidate, not the first
implementation: selected 8 MiB multi-byte tac cases improve 8.24-8.69x, column's
8 MiB table 3.65-3.66x, long rows 3.99-4.02x, tiny rows 1.54x and the grid about
1.10x. Every selected old/new row passes both windows. Against fixed local GNU
9.11, tac file reversal is 2.67-2.71x, stdin 3.47x, and selected multi-byte cases
4.19-4.47x. The short overlap reference fails the 5% dispersion threshold; its
8.17-8.86x observed ratio is not accepted. No local util-linux column oracle is
available, so column has no new upstream-target certification.

The first strict check rejected a deprecated String escape in a new test. Its
subsequent build had not run, so `final-column` still measured the binary before
delimiter classification; that phase's source snapshot is not a matching build
provenance record. After replacing the test escape and passing info/format/check,
the release build changed column's fingerprint. `column-reviewed` independently
measures that exact final artifact and preserves every older phase. Tac's final
binary matches `combined-batches` and `final-tac-upstream`. The audit verifies
all samples, hashes, outputs and thresholds without retrying noisy observations.

Local correctness passed 1,627 Wasm package tests and 118 Native test-tool tests.
The functional suite passed 2,062 cases with 19 skips before the final column
rebuild; final column is also checked by its 18 package tests, a 22-case command-only
functional replay and 120 exact baseline differentials. The full 768-case
supplemental selection has 766 exact matches and two unchanged upstream
differences. One is the previously recorded binary grep inversion/count case.
The other is GNU tac 9.11 with `-s aa` on `head\n` + 65,535 `a` bytes +
`b\nend`: the old and new Wasm outputs agree, but GNU differs at byte 65,538.
The initial failed comparison and complete classified rerun are retained;
neither difference is treated as upstream compatibility acceptance.

Nine held-out/long-input resource comparisons pass output, status and effect
checks with no stderr, timeouts or residual temporary entries. Column compares
against the imported Wasm baseline; tac compares against local GNU. Separate
Darwin kernel observations cover six old/new workloads. Column's long-record
peak falls from 46,186,496 to 32,653,312 bytes in that single observation; the
two 8 MiB tac peaks stay around 27 MB. Sampled RSS is only a lower bound, and
neither observation establishes a portable memory limit. The earlier hosted
Linux stability failures remain unresolved. No remote development/resource
workflow or exact-version publication acceptance ran for this local source.

The next column step is to measure batching the ingest/index writes for tiny
records; each record still crosses async scanner and buffered-writer calls.
Only then consider storing validated field/width metadata to avoid the second
parse, measuring its extra disk/index cost. Rg's larger count/miss gaps need
block-level discovery and line-count batching; prepared output batches target
printing separately. Grep state-certified skips must retain entropy controls.
Tac can investigate skips in the zero-prefix KMP state without weakening seam
or overlap semantics. Wc's descriptor metadata gap remains open.

### Isolated performance candidates (2026-10-27)

These experiments are prepared against `2064a16` in
`/private/tmp/cmd-next-20261027/source`, separately from the maintainer's active
release checkout. They do not publish, update registry manifests, create a PR,
or establish Linux resource/three-platform acceptance.

Selected changes are bounded batch reversal for rev, delimiter and contiguous
range specialization for cut, block-batched single-byte reversal for tac,
packed literal-automaton metadata, and an opt-in
synchronous summary callback for rg's reader path. Rev retains whole-record
ASCII rejection and exact buffered-write count/error boundaries. Its fixed
64 KiB output buffer no longer allocates a reversed copy of each record;
immutable input batches are capped at 1 MiB, with separate longest-record
accumulation. Cut's special empty-field and equal-delimiter cases are unchanged.

Tac uses reverse byte searches and a synchronous batch for ranges contained in
the same 64 KiB input block. The first boundary can still span later blocks and
uses the existing bounded positional copy. The batch adds O(block size) storage;
stdin is still completely spooled before any output. Single-byte custom/NUL
separators and before-separator mode share the same path. Multi-byte KMP and
regex paths are unchanged. Independent forward-partition tests cover all six-byte
binary separator arrangements and long records straddling 64 KiB boundaries.
Two complete local windows measured 16.33-16.77x improvement for the 8 MiB file
case, reaching 2.61-2.67x GNU tac. The stdin case improved 12.96-13.03x but remains
3.52-3.53x GNU; tiny and multiple-byte cases still exceed the target.

The literal table retains at most 1024 states and 257 byte classes. Therefore
the largest row offset is 1023 * 257 = 262911 (19 bits), and the longest accepted
nonempty literal is 1023 bytes (10 bits). A single positive Int32 stores both.
The maximum integer table payload is 1,052,672 bytes, plus classes, patterns,
construction maps and object overhead. This is an allocation bound, not RSS.

Rg's optional synchronous callback has no I/O or raising effect. Default sinks
return None. The selected summary sink reuses the same match accounting logic
on both paths; binary notifications, begin and finish remain async and ordered.
The fast loop is limited to eligible reader searches without context, inversion
or stop-on-nonmatch. Slice/multiline and output sinks retain their existing path.
Regression traces compare both dispatch modes, including binary modes, line
and byte offsets, early callback stops and zero/two-match limits.

A deeper assertion-free boolean-DFA pilot caches exact eight-byte transfers,
keyed by all 64 input bits and entry state, in 4096 slots (64 KiB integer
payload). It never uses hashes to establish matches. Repeated-input cases
improved, but random ASCII regressed about 30%. A second pilot suspended the
cache for 64 KiB after fewer than eight hits in 64 probes; the random penalty
fell to about 7-8%, while ordinary 1 MiB regex counting still regressed 2-3%.
Both variants are retained as negative evidence and excluded from the selected
candidate. Revisit with a demonstrably cheap eligibility rule or per-state
certified self-loop skips; require heterogeneous controls before integration.

Column's diagnostic-only stage instrumentation measured 575-590 ms for snapshot
ingestion and 1036-1042 ms for rendering an 8 MiB table in three observations.
The diagnostic source and Wasm are retained separately; no profiling output or
column implementation change is selected. Rendering accounts for about 64% of
these measured internal stages. The next pilot should batch table layout while
retaining the complete snapshot, Unicode display widths, bounded page cache and
error cleanup. Removing the snapshot is not justified by this evidence.

Final local checks pass 1,618 release-Wasm tests. Earlier checks on the selected
rev/cut/grep/rg changes pass 117 tool tests and 2,062 functional cases (19 skips);
the subsequent tac change passes its 54-case functional replay. Supplemental
432-case comparisons retain one baseline-equal binary grep difference and no
new regression; eight rev cases use the original Wasm rather than a Linux oracle.
Sixteen resource observations compare cut/grep/tac against fixed local GNU
binaries, including held-out and long records at 8/64 MiB and literal stress.
All output/status/effect checks pass, with no timeout or residual temporary
entry. Sampled RSS is a lower bound. Separate Darwin kernel observations on
eight old/new workloads show no process-RSS reduction from table packing; rev's
peak rises by about 1.9-2.5 MiB in the two observed shapes. Neither observation
is a Linux memory certification or a constant process-memory bound.

Measurements remain complete release-Wasm processes, including initialization,
I/O and exit, without MoonX timing, startup subtraction, sample deletion or
automatic retries. Both sides must have MAD/median <= 5% in each nine-pair
window and between-window median difference / mean <= 10%. Several early
windows failed and remain failed. Raw phases, diagnostic rg stage observations,
source snapshots and comparisons are retained under `/private/tmp/cmd-next-20261027`.
The final report distinguishes gains over the same-source baseline from the
remaining GNU/Rust ratios; selected gains do not establish the global 1-3x goal.

### Adaptive literal planner (2026-10-27)

PR #60 merged as `6705ea8` after the maintainer explicitly accepted unresolved
repeatability for that integration. Its final head passed all three development
checks; actual-main run [40406545144](https://github.com/moonbit-community/cmd/actions/runs/40406545144)
also passed Linux, macOS and Windows. Documentation PR #59 was merged first.
The exception does not turn failed resource stability into a pass, change the
5% dispersion / 10% drift rules, or authorize publication. Original observations
and the unsuccessful observer/cache/CPU interventions remain historical evidence.

The next candidate promotes the isolated literal-planner pilot into the shared
pure-MoonBit matcher. Long literals begin with the two-byte shift plan. Within
a 4096-byte progress window, at least 256 candidate verifications and more than
four candidates per progressed byte can request a bounded automaton. Switching
occurs only after every candidate at the current start has failed; the automaton
resumes at the next start. Hashes and counters never establish a match.

The compiled set owns its pattern array and lazily caches at most one automaton.
The existing 4096-byte pattern and 1024-state budgets remain. If construction
exceeds its state budget, the current scan resumes safely with shifts and no
later scan retries construction. Subsequent inputs start with shifts even when
the automaton is cached, retaining the sparse-input fast path. No input view or
record-dependent result is retained across calls. Accepted spans return directly;
the internal handoff uses a negative start that never escapes the public API.

The shift table has 16 KiB of integer payload. A cached automaton adds at most
2,105,344 bytes for transitions and terminal lengths, plus byte classes, owned
pattern references, temporary construction maps and object overhead. This is an
algorithmic table bound, not a process RSS cap. Public signatures and command
options are unchanged; the packages remain unpublished core 0.8.2 / grep 0.3.1.

The exploratory driver adds thirteen real grep workloads: shared/diverse-first
collision families at 64 KiB, 256 KiB and 1 MiB, sparse inputs at 1/64 MiB, a
collision-to-sparse sequence, dense hits and a construction-budget fallback.
All previous 23 manual performance workloads remain. The separate literal
resource profile adds sampled and kernel RSS observations for both collision
families, sparse input and failed construction, including output/status/effects,
timeouts and residual temporary entries. Ordinary timing does not enable RSS
observation. Detailed results and remaining limits are recorded with the
candidate's validation; Linux stability remains a separate unresolved question.

Deeper follow-ups are reducing the duplicated terminal-length table without
adding a hot-loop division, and bounded block-transfer summaries for repeated
regex suffix states. Neither is selected: require independent sparse/dense and
large-alphabet measurements, cache-exhaustion checks and a bounded memory model
before changing those engines.

Local macOS arm64 validation compares real release-Wasm grep against frozen
merged-main `6705ea8` and, separately, the existing GNU grep 3.12 build. Each
comparison has two windows of one warmup plus nine alternating pairs, including
runtime initialization, I/O and exit. All 26 workloads (thirteen new and thirteen
existing grep controls) passed exact status/stdout/stderr comparison in both
windows. All 26 old/new comparisons met the unchanged stability formulas; only
21/26 GNU comparisons did, with five noisy millisecond-scale reference rows.
Those failed windows are retained and were not retried.

| Workload | New / old median ms, first window | Old/new speedup, both windows |
| --- | ---: | ---: |
| Shared-first collisions, 1 MiB | 32.23 / 459.23 | 14.25x / 14.63x |
| Diverse-first collisions, 1 MiB | 33.36 / 466.39 | 13.98x / 14.26x |
| Shared-first sparse, 64 MiB | 47.81 / 47.81 | 1.00x / 1.01x |
| Diverse-first sparse, 64 MiB | 47.96 / 47.86 | 1.00x / 1.01x |
| Collision prefix then sparse, 64 MiB | 50.03 / 52.00 | 1.04x / 1.05x |
| Dense hits, approximately 1 MiB | 19.17 / 20.31 | 1.06x / 1.06x |
| Trie-budget fallback, 64 KiB | 42.30 / 42.65 | 1.01x / 1.00x |

The first integrated variant allocated an extra result object per hit. It
retained collision gains but slowed the existing many-pattern and dense count
controls by about 15%. Returning the existing span directly removed that
regression from dense counts (under 0.5% in both final windows). Many-pattern
and short-pattern controls still show about 2–3% regressions; these small paired
observations do not establish their general significance. The original rejected
variant and its full windows remain alongside the refined result.

This does not achieve every 1–3x GNU target: final shared/diverse collision
ratios are about 7.7–8.0x / 12.9x; budget fallback is about 23–24x. Sparse
64 MiB ratios are about 2.7x / 0.93x. Faster relative-to-old execution is not
equivalent to GNU parity or a Linux stability correction. Raw reports, immutable
Wasm copies, hashes and scripts are indexed under
`test-reports/adaptive-literal-20261027/`; the complete local working evidence
remains in `/private/tmp/cmd-adaptive-20261027/`.

Local validation passed 1,611 release-Wasm package tests, 117 Native tool tests,
and 2,062 functional cases with 19 explicit skips. Eight sampled resource smoke
comparisons passed status/output/effects with no timeouts or residual temporary
entries. Sampled RSS is only a lower bound; Linux kernel observations and the
expanded full CI profile are separate checks. Generated public interfaces are
unchanged. No package was published or frozen expectation rewritten.

### Stability investigation (2026-10-27)

Linux resource run 40346450167 passed 95 resource comparisons and the exact
outputs of both 23-case performance windows, but six workloads failed the
unchanged 5% dispersion or 10% drift thresholds. GNU cut samples exhibit an
order-associated timing difference in both windows; this does not identify
its physical cause or explain every Wasm-side failure. At this investigation
stage the merge was conditional on complete development and resource results;
the later, explicitly scoped integration exception is recorded above.

The explicit `stability-diagnostic` profile compares the existing observer,
a Native observer, a fixed between-arm pause and single-CPU affinity while
keeping the candidate Wasm and inputs fixed. These are diagnostic interventions,
not adopted execution settings. Preserve every original and diagnostic sample;
do not use an intervention's completion status as stability acceptance. Select
a correction only after the observations support it, then require the complete
resource profile with the existing thresholds and fresh final-head checks.

The first controlled Linux x64 run, 40395472012 at 87dc76b, completed every
window but produced only 17/23 stable cases for either observer and 14/23 for
either settling or one-CPU affinity. None is a selected correction. A second
diagnostic phase tests equal input preloading and adds minimal direct-Wasm
controls plus separate per-invocation kernel counters. Counter wrappers and
their coarse CPU-time resolution remain diagnostic only. Preserve the original
short-input workloads and complete process timing; changing sample units or
averaging away single-process variation would require a separate acceptance
decision, not a stability fix.

The second run, 40398697579 at 8fcdad5, completed the 25-case cache/control
selection, but Native control and preloading each passed only 16/25 stability
rows, and GNU-time observation passed 15/25. Empty-input Wasm `true` itself
showed 11.9% between-window drift. This establishes a contribution outside
text-processing workloads without attributing it uniquely to the runtime or
host. Input preloading is not adopted. The Linux-only `cpu` diagnostic adds
`perf stat --null` accounting, with no PMU permission changes, to distinguish
CPU consumption from elapsed variation. Its wrapper overhead and child CPU
accounting are explicitly separate from unchanged acceptance measurements.

### Performance wave 4 candidate (2026-10-26)

This extends unpublished core 0.8.2 and grep 0.3.1, with wave-3 commit
`d9107de` as the frozen comparison. Command options, help, catalog contracts,
published coordinates and published expectations are unchanged. Measurements
remain direct release Wasm through `moonrun`, including runtime initialization,
I/O and exit, with no MoonX timing or startup subtraction.

Grep compiles four or more fixed patterns into one `LiteralSet` when word/whole
filters are absent. Nonempty sets have at most 4096 total literal bytes. If the
shortest literal has at least three bytes, a 4096-entry table skips on hashed
two-byte suffixes of the shortest prefix, then verifies complete candidate
literals. The conservative shifts follow the multiple-pattern method in
[Wu and Manber, TR 94-17](https://cs.arizona.edu/sites/default/files/TR94-17.pdf).
Hash collisions reduce skips or add verification work; they cannot establish
a match. Shorter patterns select a byte-class Aho-Corasick table with at most
1024 states and 257 classes, including the other-byte class. Transition and
accepted-length tables together use at most 2,105,344 bytes of integer payload;
construction maps and object overhead are additional. Longer-pattern sets do
not construct this trie. Empty or over-budget sets retain per-pattern search.

`LiteralSet.find_span` preserves earliest-start, longest-end selection.
`find_any` stops after a verified occurrence without resolving longest ties.
For delimiter-free patterns it cannot skip an earlier matching record, so the
count path uses it to find a record and skip its remaining hits. Inversion
counts complete records minus matched records; incomplete tails retain the
record path. Case folding retains per-record matching, and word/whole filters
retain the original fixed matcher. The public API adds only the opaque literal
set and its construction, occurrence, span, boolean and delimiter queries.

Long-record regex endpoint queries now skip a region only after proving that
every consumed byte leaves the forward DFA in the same state. If that region
reaches the record end, one constant-size certificate records the state, suffix
start and acceptance. Later queries reaching the same state inside that suffix
can reuse its result. The certificate belongs to one immutable record, supports
resumed or decreasing start offsets, and is never shared between records.
Selection starts at 4096 remaining bytes; actual self-loop skips require at
least 64 remaining bytes. Ordinary short searches retain the scalar endpoint
loop. Cache exhaustion still reruns the current query through the existing
fallback. This handles a concrete repeated-suffix case without claiming a
general linear-time bound for ambiguous regex enumeration.

Final local macOS arm64 observations use pinned local GNU 9.11/3.12 builds,
regular-file stdin, captured stdout, one warmup and nine alternating pairs.
All 15 final rows passed exact status/stdout/stderr comparison. Candidate and
GNU columns are median milliseconds; speedup comes from a separate paired
comparison against wave 3, rather than dividing across different runs.

| Workload | Candidate | GNU | GNU ratio | Wave-3 speedup |
| --- | ---: | ---: | ---: | ---: |
| 16 fixed patterns, count, 8 MiB | 26.74 | 4.90 | 5.46 | 2.39x |
| Same patterns, count, 64 MiB | 91.05 | 28.59 | 3.18 | 4.49x |
| Same patterns, spans, 1 MiB | 21.03 | 3.50 | 6.00 | 1.32x |
| 16 fixed patterns, miss, 8 MiB | 20.71 | 6.16 | 3.36 | 1.50x |
| Four short patterns, count, 64 MiB | 81.75 | 22.54 | 3.63 | 1.42x |
| Four dense patterns, count, 64 MiB | 96.00 | 28.11 | 3.42 | 1.21x |
| 16 distributed prefixes, miss, 64 MiB | 76.16 | 38.83 | 1.96 | 1.70x |
| `a\|a.*z`, spans, 8 KiB of `a` | 16.05 | 45.19 | 0.36 | 7.60x |
| Same expression, 16 KiB of `a` | 18.13 | 172.61 | 0.11 | 25.44x |
| Regex spans, 8 MiB / 1 MiB records | 83.04 | 19.91 | 4.17 | 1.09x |
| Original regex spans, 1 MiB | 29.44 | 9.32 | 3.16 | 0.98x |
| Many regex spans, 1 MiB | 32.71 | 14.64 | 2.23 | 0.98x |
| Single fixed count, 64 MiB | 60.01 | 18.27 | 3.28 | 1.00x |
| Regex count, 64 MiB | 104.85 | 35.68 | 2.94 | 1.00x |
| Regex miss, 8 MiB | 18.58 | 2.35 | 7.92 | 0.98x |

The 16-pattern hit set contains `absent0` through `absent14` and `gamma`;
the miss set replaces `gamma` with `absent15`. Additional short, dense and
distributed-prefix rows prevent conclusions from resting on that shape alone.
Exact arguments and reproducible corpora are in `tests/benchmark/explore.mbtx`.
The `a|a.*z` rows expose repeated suffix scans in both the previous candidate
and GNU, and do not represent all regex workloads. Short span/miss rows show
about 2% regressions in the final pairs; this small window does not establish
their significance. The candidate Wasm grows from 421,685 to 434,882 bytes.

Two rejected approaches constrain the next design. Aho-Corasick alone improved
the original 64 MiB multi-pattern count from 405 to 133 ms, but regressed the
8 MiB miss from 31 to 33 ms. Selecting two-byte shifts for longer patterns
improved both. Applying self-loop skipping to the reverse start bitmap made
long records worse, about 125 versus 89 ms, so that experiment was removed.
The retained forward skip gives a modest long-record gain; reusing its proven
suffix gives the much larger overlapping-match gain. `reverse-trial.mbt` and
the raw intermediate reports preserve the negative experiment.

The next deeper candidates are bounded block-transfer summaries for forward
states that revisit non-self-looping suffixes, and a literal planner that can
switch from shifts to an automaton when verification collisions become dense.
These remain unimplemented: require independent collision-heavy, sparse/dense
and record-size scaling measurements, preserved leftmost-longest/offset/error
semantics, and explicit memory bounds before selecting them. A universal
automaton or universal skip strategy is not supported by this wave's results.
The general long-record and small-input gaps above remain outside the 1–3x
exploration target; further work needs a measured scan/I/O breakdown.

Validation passed 1,604 release-Wasm package tests, 117 Native tool tests and
2,062 functional cases, with 19 explicit skips and zero failures. The expanded
independent GNU comparison matched 792 of 796 cases. All four mismatches are
the existing empty-pattern `grep -v -c` difference, reproduced with frozen
wave-3 Wasm; the GNU-equivalence run remains failed. New cases cover both
literal plans, folded/word/whole/NUL options, partial and cross-buffer records,
resumed views, hash collisions, trie-budget fallback, earliest endpoint versus
earliest start, and interleaved suffix searches on different records.

Raw reports, source patch, executable/corpus hashes, frozen artifacts, scripts
and stage durations are indexed by
`test-reports/performance-wave4-evidence/manifest.json`. Final rebuilt Wasm is
byte-identical to the measured artifact. These are diagnostic observations,
not formal 105-pair/p95/confidence acceptance, sealed Linux parity, Linux/Windows
validation, pipe-throughput/RSS acceptance or published-consumer acceptance.
No package was uploaded; the original checkout remains unchanged.

### Performance wave 3 candidate (2026-10-26)

This extends unpublished core 0.8.2 and grep 0.3.1 from wave 2, retaining the
pure MoonBit and direct release-Wasm measurement boundaries. No MoonX timing or
startup subtraction is used. The frozen comparison commit is `340b356`.

`RecordMatcher.search_bytes` borrows a record and returns resumed byte offsets.
The package-level `search_bytes` constructor shares fallback text conversion
across patterns. Literal searches use bytes directly. Other eligible span
searches use a reverse unanchored DFA to mark every feasible start, then an
anchored forward DFA to select the longest endpoint at the earliest start.
The start/end separation is related to the paired automata described by
[Rust regex-automata](https://docs.rs/regex-automata/0.4.18/regex_automata/dfa/regex/struct.Regex.html).
Here the reverse pass records all feasible starts to preserve GNU
leftmost-longest selection: in `a.*z|b` on `abz`, the earlier `a` start wins even
though the `b` alternative accepts sooner.

Each DFA has at most 256 states and 256 byte classes; eligible programs have at
most 256 instructions and no assertions or backreferences. Cache exhaustion
disables the pair and reruns the current query through the retained span engine.
Word/whole filters use the span plan, and assertion/reference/large-program
fallbacks share one lazily decoded record. Each eligible search retains a bitmap
of `floor(record_bytes / 64) + 1` 64-bit words. Aggregate bitmap storage grows
with record size and pattern count. This is not an RSS cap. The reverse pass is
reused across resumed searches, but forward longest-match searches can revisit
suffixes for ambiguous patterns; no general linear-time enumeration claim is
made. Literal and nullable searches preserve empty spans and progress rules.

Grep's span emitter resumes a record after its 64 KiB output threshold. Both
matching and output accumulation run synchronously inside buffered input;
only refill and output flush cross async boundaries. Output storage follows a
flush block plus the largest emitted match/prefix, without accumulating the
expanded output of all matches in a long record. Binary decisions, offsets,
partial input-error records and failed-write non-replay remain covered. A
single fixed literal count can locate matching records directly and skip repeat
hits in the same record; case/word/whole filters and literals containing the
record delimiter retain the record path.

Final local macOS arm64 observations use the same GNU 9.11/3.12 builds, one
warmup and nine alternating pairs with exact status/stdout/stderr comparison.
Input is a regular file and stdout is captured. Times are median milliseconds:

| Workload | Candidate | GNU | Ratio |
| --- | ---: | ---: | ---: |
| grep -Eo '[0-9]{4}.*gamma', 1 MiB | 28.62 | 9.06 | 3.16 |
| grep -Eo '[a-z]+', 1 MiB / many matches | 31.73 | 14.45 | 2.19 |
| grep -o alpha, 1 MiB | 21.32 | 6.21 | 3.43 |
| regex spans, 8 MiB / 1 MiB records | 89.88 | 19.81 | 4.54 |
| grep -wEo '[a-z]+', 1 MiB | 59.52 | 30.29 | 1.96 |
| grep -Eo 'a?', 1 MiB | 64.32 | 66.13 | 0.97 |
| grep -Fc alpha, 8 MiB | 20.90 | 3.59 | 5.82 |
| same fixed count, 64 MiB | 59.70 | 18.00 | 3.32 |
| regex count, 64 MiB | 104.90 | 35.45 | 2.96 |
| regex miss, 8 MiB | 18.04 | 2.35 | 7.69 |

Separate final pairs against wave 2 measured 3.24x for the original span row,
4.08x for many matches, 2.00x for literal spans, 3.64x for long records, 1.87x
for word-filtered spans and 3.85x for nullable spans. Fixed counts improved
1.06x/1.24x at 8/64 MiB. Regex counting did not improve: the 64 MiB pair was
104.48 versus 103.48 ms, and the miss pair 18.52 versus 17.47 ms. The candidate
Wasm also grew from about 388 to 412 KiB. These observations do not isolate the
cause of the small counting regressions.

The staged experiment is useful evidence: byte views alone took 94.56 versus
93.41 ms on the original span workload, so removing conversion was insufficient.
The endpoint pair reduced it to 37.85 ms; synchronous output accumulation then
reduced it to about 31.81 ms, and buffered-record emission to about 28.68 ms.
An overlapping test/measurement attempt is excluded; the output-accumulation
figure uses the later serialized run. The next experiments should target
revisited endpoint suffixes on long records, word-aware endpoint states, and
multi-literal block search. Their additional gains are unverified. Benchmark
both sparse and dense matches and record-size scaling before broadening any
engine selection; increasing buffers or removing conversions alone has not
resolved these gaps.

Validation passed 1,597 release-Wasm package tests, 117 Native tool tests and
the full functional suite (2,062 passes, 19 explicit skips, zero failures).
The independent local GNU set matched 684 of 688 cases. The four mismatches
are the existing empty-pattern `grep -v -c` output difference, reproduced with
wave-2 artifacts on all four inputs. No new mismatch appeared in that set.
Additional regressions cover earliest-start versus earliest-end selection,
resumed offset views, all byte values, cache exhaustion with retained searches,
shared fallback conversion, multi-pattern span selection, NUL prefixes and
input/output failures. Package interface changes are limited to the new byte
search entry points and opaque `RecordSearch` type.

Raw reports, executable/corpus hashes, frozen Wasm artifacts, scripts and stage
durations are indexed by `test-reports/performance-wave3-evidence/manifest.json`.
Reproduction uses the extended `tests/benchmark/explore.mbtx` and the retained
`/private/tmp/cmd-perf-wave3-20261026` lab. These are selected diagnostic medians,
not formal 105-pair/p95/confidence acceptance, sealed Linux parity, three-host
validation or published-consumer acceptance. No package was uploaded.

### Performance wave 2 candidate (2026-10-26)

This extends the same unpublished coordinates from wave 1. Product code and
diagnostic orchestration remain pure MoonBit. Direct release-Wasm launch-to-exit
timing includes runtime initialization, I/O and exit; MoonX is not measured.

`RecordBatch.each_while` invokes a synchronous consumer until its output needs
flushing. It avoids a RecordView/Option result per record and checks the first
four bytes before setting up a delimiter search. Cut selects its byte or field
consumer once per input, writes singleton byte selections directly, and stops
field traversal after the last selected field. Existing equal-delimiter and
empty-selection compatibility paths remain separate. Uniq reuses unchanged key
views. Output flushing stays asynchronous, with the same partial-write and
input-error behavior as wave 1.

Grep checks a conservative mandatory literal once per buffered block. Only
complete records can be rejected; inversion and context disable this path.
Refill still inspects binary input and retains incomplete tails. Offsets and
record numbers advance with a word-at-a-time delimiter count bounded by the
BytesView, including its start offset. Count consumers process the remaining
complete records synchronously without record objects or async continuations.

The deeper engine changes are lazy construction and a flat DFA transition table:
the current state is a row offset, removing object lookup and multiplication
from each byte transition. At most 256 subsets and 256 byte classes occupy the
table; the existing program/state limits and fallback remain. A separate lazy
span plan precomputes epsilon closures for assertion-free, reference-free
programs of at most 256 instructions. It reuses ordered integer worklists and
preserves leftmost-longest selection, including resumed, word and whole-record
search. Closure storage is quadratic in program size, bounded by 256 squared
entries, plus worklists. Literal patterns keep their literal path; assertions,
backreferences and larger programs keep the existing engines. This is an
allocation/work bound, not measured RSS acceptance.

Final local macOS arm64 diagnostic medians use the same GNU 9.11/3.12 builds,
regular-file stdin, captured stdout, one warmup and nine alternating pairs per
row, with exact status/stdout/stderr comparisons:

| Workload | Candidate ms | GNU ms | Ratio |
| --- | ---: | ---: | ---: |
| cut -b 1-8, 8 MiB / 80-byte records | 16.21 | 4.93 | 3.29 |
| cut -f 1,3, same input | 33.37 | 9.86 | 3.38 |
| cut -b 1, 8 MiB / 2-byte records | 69.10 | 24.32 | 2.84 |
| uniq, 8 MiB / 80-byte records | 23.78 | 14.82 | 1.60 |
| uniq, 8 MiB / 2-byte records | 257.51 | 102.37 | 2.52 |
| uniq -c, 8 MiB / identical records | 16.09 | 7.82 | 2.06 |
| grep fixed count, 8 MiB | 22.16 | 3.81 | 5.82 |
| grep fixed miss, 8 MiB | 16.51 | 2.10 | 7.86 |
| grep -Ec '[0-9]{4}.*gamma', 1 MiB | 16.29 | 2.17 | 7.52 |
| same regex count, 64 MiB | 103.15 | 35.64 | 2.89 |
| grep regex miss, 8 MiB | 17.47 | 2.32 | 7.54 |
| grep -Eo span extraction, 1 MiB | 94.98 | 9.19 | 10.33 |

Separate final pairs against frozen wave-1 artifacts measured 4.96x for short
cut records, 2.41x for short uniq records, 2.67x for the 64 MiB regex count,
2.34x for regex rejection and 1.39x for span extraction. Normal cut and uniq
improved about 1.36x. Incremental prototypes attribute useful additional gains
to the synchronous count loop (about 274 to 131 ms), then the flat DFA table
(about 131 to 102 ms). Precomputed span closures reduced the span workload from
about 129 to 94 ms. These observations support engine/data-layout specialization
beyond simply increasing the input buffer.

Validation passed 1,584 release-Wasm package tests, 117 Native test-tool tests,
and the full functional suite (2,062 passes, 19 explicit skips, zero failures).
The span oracle matrix compares the new matcher with the retained tagged
engine, across resumed starts and word/whole filters. New regressions cover
visitor stop/resume, retained views, offset byte counts and cross-block filtering.
An independent 244-case local GNU comparison covers binary/NUL data, long
records, inverse/context output, groups and backreferences: 242 match exactly;
two retain an existing difference for empty-pattern `grep -v -c` (candidate
prints `0`, GNU 3.12 exits without stdout; both exit 1). Both mismatches reproduce
with the frozen wave-1 artifact. No new mismatch appeared in that set, but this
is not a full GNU parity pass. Lifting that difference requires a separate
early-exit/stdin-preservation contract and pinned three-host regressions.

The next measured bottleneck is span extraction: it remains over 10x GNU even
after closure precomputation. A byte-view span engine that avoids intermediate
String conversion and an endpoint-oriented search plan are candidates for the
next experiment, not established gains. Fixed-string search also still scans
records after a positive block filter; a block search that locates candidate
records once, including multiple patterns, should be tested separately. Ordinary
cut remains slightly above 3x. These extensions must preserve leftmost-longest,
binary/context/early-exit semantics and the retained fallback engines, then pass
held-out workloads before acceptance. Short-command timing is not corrected by
subtracting startup, and an observed median below 3x is not a formal pass.

`tests/benchmark/explore.mbtx` reproduces paired measurements. Wave-2 scripts,
raw reports, artifact hashes and validation logs are retained in
`test-reports/performance-wave2-evidence/manifest.json`; the prototype workspace
is `/private/tmp/cmd-perf-wave2-20261026`. There is no formal 105-pair result,
sealed Linux parity, Linux/Windows validation, publication or exact-version
consumer acceptance for this change. Published manifests remain frozen.

### Performance wave 1 candidate (2026-10-26)

The implementation target is direct release-Wasm elapsed time within 1-3x of
fixed GNU/Rust counterparts, excluding MoonX resolution/launch costs. Runtime
startup, command I/O and exit remain timed. This supersedes the prospective 1.5x
performance threshold, not historical verdicts or correctness acceptance.

Cut and uniq consume immutable record batches with synchronous byte-view
processing and 64 KiB output thresholds. Reads are at most 1 MiB; only split
records are assembled. Views may retain their backing block. Storage follows
the largest input/output record, delimiter expansion and a few blocks, not all
records. Failed flushes consume their queue before the write, so deferred
cleanup cannot replay a partially written prefix. Input errors flush completed
output without manufacturing an EOF record. Cut's special equal-delimiter and
empty-selection behavior is preserved. Wc uses 16-byte SIMD newline and C-space
masks with a carried word-boundary bit; display-width requests retain scalar
counting. Both -m and -c continue to count bytes.

Grep separates boolean acceptance from leftmost-longest span extraction. A
conservative mandatory literal can reject a record; an assertion-free program
of at most 256 instructions can use a lazy byte-class DFA capped at 256 subsets.
Cache exhaustion disables that cache and reruns the current record through the
span engine. Assertions, word/whole filters and backreferences keep existing
acceptance rules. Span-only Thompson searches retain ordered starts in reusable
integer worklists. Captured searches keep distinct tag states. Buffered grep
records are consumed synchronously while its existing refill path preserves
binary detection, byte offsets, partial-error records and early exits.

These decisions draw on the buffer/consume separation in
[Rust BufRead](https://doc.rust-lang.org/std/io/trait.BufRead.html) and the
specialized engines and scratch state described by
[regex-automata](https://docs.rs/regex-automata/latest/regex_automata/meta/index.html).
All implementation and orchestration here remain pure MoonBit.

Local macOS arm64 observations use GNU coreutils 9.11 and grep 3.12 built with
`-O3`, one warmup and nine alternating pairs, exact output/status/stderr checks,
regular-file stdin and captured stdout. Representative medians, in milliseconds:

| Workload | Candidate | GNU | Ratio |
| --- | ---: | ---: | ---: |
| wc -l, 64 MiB | 19.32 | 9.53 | 2.03 |
| wc -w, 64 MiB | 23.09 | 56.97 | 0.41 |
| cut -b 1-8, 8 MiB / 80-byte records | 23.01 | 4.86 | 4.73 |
| uniq, same records | 33.48 | 14.91 | 2.25 |
| grep -Ec '[0-9]{4}.*gamma', 1 MiB | 20.94 | 2.13 | 9.84 |
| same grep expression, 64 MiB | 276.61 | 34.95 | 7.91 |
| grep regex miss, 8 MiB | 41.49 | 2.14 | 19.40 |
| grep -Eo span extraction, 1 MiB | 129.59 | 9.07 | 14.28 |
| cut, 8 MiB / 2-byte records | 343.34 | 21.41 | 16.04 |
| uniq, same short records | 621.49 | 101.29 | 6.14 |

The earlier buffer-only prototypes took about 86 ms for cut and 91 ms for uniq.
Fresh paired comparisons against the original release artifacts measured about
84x/61x improvements for cut/uniq, 5.6x/7.3x for wc line/word counting, and 34x
for the 1 MiB regex count.
The compact regex worklist took about 92 ms on the 1 MiB regex row before DFA
and buffered iteration. Required-literal rejection reduced the regex miss from
83 to 41 ms. The word SIMD path is a further change beyond the newline pilot.
Increasing record reads from 64 KiB to 1 MiB had only a small effect; it does not
resolve the short-record bottleneck. These are diagnostic medians, not a formal
performance pass, Linux oracle parity or a publication claim.

The next experiments should fuse scanning, selection and output for dense short
records; skip nonmatching blocks with safe literal candidates before record
materialization; and accelerate span endpoints without changing leftmost-longest
or backreference behavior. A bigger buffer alone is not sufficient. Gate any
extension on held-out short/long/duplicate/binary inputs, errors and cancellation,
followed by three-host Wasm correctness and qualified performance sampling.
Reproduction uses `tests/benchmark/explore.mbtx`; raw local evidence is retained
under `/private/tmp/cmd-perf-lab-20261026/`, with final manifests and hashes.
Published manifests remain frozen; candidate coordinates are core 0.8.2,
cut/uniq/wc 0.2.3 and grep 0.3.1. No package was uploaded.

### rg migration candidate (2026-10-26)

The rg module retains its reader/sink algorithms and makes actual reads, sink
writes, directory advancement and stdout flushing asynchronous. It does not
load ordinary files or accumulate search stdout as an async workaround. Existing
multiline and sorted traversal retain their explicit larger storage paths.
The removed `-z` adapter survives only in Git history; no decoder/resource claim
applies to the candidate. Unavailable stdin kind is an explicit status-2 search
boundary, with explicit paths and `-` covered by portable contracts. Automatic
terminal presentation chooses plain output; it is not reported as a successful
terminal query. Lift these limits only after public APIs and three-host Wasm
regressions exist. Evidence and remaining checks: [rg support profile](../../docs/compatibility.md#rg-candidate).

Preserve byte streams, final newlines and partial output. Set LC_ALL=C explicitly in differential fixtures; inherit caller locale in real commands. C-byte collation tests do not certify non-C behavior. Keep bounded sort and descriptor-follow tail as declared subsets.

## Alternatives and compatibility cost

The shared core 0.8.0 line scanner owns one 64 KiB read buffer, tracks the
unconsumed range and uses the public single-byte search operation. It does not
rescan an accumulated prefix or copy the remaining chunk for each line. Only
cross-chunk records accumulate; returned lines own their bytes before refill.
Storage follows the largest record encountered plus a block, rather than the
number of records. The existing constructor/next calls and delimiter behavior
remain; the generated structural interface records the new state.

Plain cat copies reuse a 64 KiB buffer across operands. Wc computes only selected
counters. Its published implementation follows the frozen C byte profile: both -c and
-m count every byte, including malformed UTF-8, with no decoder or pending
sequence state. The earlier UTF-8 counter observations remain historical.
Strings retains a candidate prefix only until the requested minimum, then
streams its printable continuation with 64-bit input offsets.
Head batches record/byte/header output and flushes completed output on input
errors. Shared new-file copying uses a reusable 64 KiB buffer; this changes
neither replacement preflight nor filesystem capability decisions.
Sort prepares comparison keys once, carries stable sequence IDs through disk
runs and merges at most sixteen inputs. Its default 64 MiB budget counts
record/key payloads, bookkeeping and reserved buffers; active/oversized records
and runtime allocation overhead remain explicit additional costs. Preserve
first-representative unique behavior and error cleanup before raising the budget
or widening options; require measured RSS before claiming a memory cap.
These implementations were published on 2026-10-25 with package and command
regressions. Their release does not establish formal performance acceptance.

Rev selects the fixed Linux C-locale util-linux 2.40 profile. It reverses
ASCII/NUL records without decoding and rejects a record containing a non-ASCII
byte before writing it. Completed records remain on stdout, their count appears
in the diagnostic, and later named inputs continue. PR #54's pinned Linux
Native/Wasm observation for `o6-rev-invalid-c-byte` establishes that behavior;
the older macOS provider's high-byte acceptance is not Linux parity.

Reject universal newline normalization, whole-output trimming and forced locale. Command substitution removes trailing LF only, preserving spaces and embedded newlines. Grep separators require requested context; base64 -w0 emits no newline. Full locale-aware comparisons remain unverified.

## O1 selected text options

The published 0.2.2 commands add cut complements/output delimiters, uniq
member/group output, comm column delimiters/totals, join ASCII-folded keys/
headers/automatic output fields, and wc total policies. Cut keeps distinct
adjacent explicit spans when an output delimiter makes their boundary visible.
Uniq retains only its current key and pending record; member output does not
buffer an entire duplicate group. Comm/join retain their streaming merge and
current equal-key runs. Default disorder diagnostics preserve the GNU output
prefix and continuation; explicit order checking stops early. Join's automatic
field counts freeze on the first record, and explicit output lists accumulate.

Wc total-only output has no per-input rows, names or padding. Opened inputs keep
their observed counters after a read error, and later inputs still run. Numeric
alignment for named files uses public kind/size metadata; standard input uses
the seven-column stream layout for multiple counters. Exact GNU alignment for
a regular file redirected to stdin is not claimed: released async 0.22.5 exposes
Input.fd but no public descriptor kind/size query or fd-to-File borrowing API.
Lift that layout limit only when such a public API and Native/Wasm regular-file/
pipe/partially-consumed/repeated-stdin regressions exist. This does not prevent
total-only output or named-file counting. Do not import internal event-loop
metadata functions or add host-process workarounds.

## O2-O4 sort, paragraphs and tab stops

Sort preserves sequence IDs for stable ties and first representatives. Random
ordering caches MD5(seed16 || transformed key), then the effective key for hash
ties, within the existing run format and accounting. Explicit sources consume
exactly sixteen bytes; an ineffective random-source option does not open its
source. A public random seed supplies ordinary `-R`. Merge assumes its inputs
are already ordered, as GNU does; it does not validate or repair them. This
corrects the optimization plan's earlier wording about merge validation.
Fatal errors use GNU status 2, including failed temporary-file creation. The
host policy regression retains the blocked-write diagnostic and empty stdout;
its earlier status-1 expectation belonged to the pre-O2 generic error handler.
Input read diagnostics are scoped to reads, so spool failures retain their
actual operation instead of being labeled input failures.

Ordinary named output consumes all inputs before truncating an existing file,
including an input alias. New output creation and late-read failures retain
their observed ordering. Existing streaming merge output retains the narrower
identity/error-effects limit in ADR-0004. No arbitrary PRNG shuffle, path-name
identity check or content hash substitutes for GNU behavior.

Fmt reuses its paragraph optimizer with first/continuation indentation and
prefix metadata. Split mode takes precedence over crown mode, then tagged
mode. Tagged paragraphs retain continuation indentation across paragraphs;
prefix spaces affect matching, and unmatched EOF records preserve their bytes.
Paragraph buffering and locale widths remain separate resource/profile work.

Expand and unexpand share one tab-stop parser and cursor. Repeated lists
accumulate; `/N` extends the absolute grid and `+N` extends from the last fixed
stop. Trailing zero suffixes follow GNU's no-extension behavior. Signed 64-bit
stops, backspace and ordinary CR columns remain byte operations. Unexpand's
first-only policy overrides explicit/all-by-tabs policy regardless of order.

Selected GNU cases and named package regressions supply Native/Wasm evidence;
private development observations remain distinct from committed PR/main,
formal performance and publication acceptance.

## Published split, display and pipe profiles

Split uses bounded reads and owned spools for total-dependent layouts. Byte,
line-aligned and round-robin selection preserve empty partitions, elision,
suffix state and completed files on later failure. `--filter` supplies each
piece through a public pipe to the existing pure MoonBit Session, with `$FILE`
in its environment. Actual signal termination remains separate from an
ordinary exit 141; this adds no host-shell fallback or new shell language.
GNU 9.11's undefined alphabet indexing for hexadecimal FROM=a-f is outside the
parity domain; the workspace deliberately uses mathematical base-16 names.

Csplit's suffix descriptor compiles one selected integer conversion, flags,
width, precision and literal percent. Suppress-matched applies to the adjusted
split boundary, including repeated and negative-offset patterns. Rev and tac
process operands in order without invented separators. Tac compiles GNU Emacs
C-byte regexes and selects rightmost start/longest end, with explicit progress
for nullable separators. The R resource contracts below distinguish fixed
separators from the matcher path's whole-input storage.

Od decodes the frozen Linux amd64 float profile, including binary16, bfloat16,
binary32/64, x87 Extended80 and binary128, through the shared numeric package.
Its strings and traditional offset/label paths retain their own termination,
radix and option-conflict rules. Hexdump compiles custom formats into a small
format representation; raw `%c`/`%s` bytes, partial elements, multiple formats,
address/final-address units, iteration and explicit `_L` colors are observed
against util-linux 2.40. Automatic color behavior on an interactive terminal is
unclaimed without a public terminal query. Undefined/nonterminating upstream
format combinations are not golden contracts.

Forward hexdump stdin skip now reads/discards and preserves the equivalent
named-file display. This is a selected extension: the fixed util-linux 2.40
pipe path reports Illegal seek. The former boundary ID is a positive
oracle=false case, not a GNU-pipe parity claim. Xxd likewise reads/discards
forward stdin positions and uses public size/read-at for wide named-file seeks.
Backward/end-relative stdin requires a public seekable input; new output files
support reverse backpatching, while existing outputs retain ADR-0004's limit.
Cmp byte notation and strings output separators preserve C byte names and
unterminated accepted strings without a complete output buffer.

Tail `-z` selects NUL record boundaries while preserving final terminators,
positive origins, byte mode and ordinary multi-file headers. Tee's explicit
warn/warn-nopipe/exit/exit-nopipe and `-p` policies classify real public pipe
errors and preserve observed later-sink and prefix effects. The test scenarios
actually close stdout's pipe reader; their observations are status, stderr and
file type/content, not captured stdout. Default tee cannot restore GNU SIGPIPE
termination because the released runtime ignores it and exposes no public
restore/raise operation. It reports the registered exact status-2 rejection
with the created sink empty, rather than inventing signal status -13. Lift
this boundary only after a released signal API and actual Native/Wasm
closed-pipe termination/prefix/cleanup comparisons pass.

Selected cases, package tests, generated mktemp relationships and real
closed-pipe scenarios retain these published profiles. Current delivery checks
run them through Wasm and exact-version MoonX as applicable. They do not certify
RSS bounds or the formal direct-Wasm performance targets.

## R streaming and temporary-storage contracts

The R release published column/rev/tac **0.1.4**, csplit **0.2.1**, split
**0.1.3**, sort **0.2.3** and core **0.8.1** on 2026-10-25. Dependency
coordinates were unchanged. The changelog records local MoonX acceptance and
the later three-platform replay separately from resource/performance claims.

Rev consumes and validates one record, then reverses ASCII/NUL bytes into one
record-sized output buffer. Its storage is O(64 KiB + longest record); a late
input failure retains completed output. It does not retain all input records.

Split streams byte/line modes. Total-size layouts use a regular file's observed
size or an owned spool; a live regular file is not an immutable snapshot.
Line-byte mode spools its pending record prefix instead of accumulating an
arbitrarily long line. Round-robin ordinary outputs close after each record;
their name/state entries remain O(visited pieces). Round-robin filters retain
one live pipe and shell task per visited piece, plus any child/filter-owned
resources; they do not claim a fixed process or memory bound. Completed files
remain after a later read, write, suffix or filter error.

Csplit first records a single input snapshot and a disk index of 64-bit line
boundaries. It retains two caches of at most 64 KiB each, a current regex line
and the created-output paths required for cleanup. Disk use is input bytes
plus eight bytes per boundary, including the initial entry. Numeric pattern
and offset parsing, and a single regex line's matcher indices, retain their
existing signed 32-bit limits. Input or spool failure precedes output creation;
later failures remove owned fragments unless `-k` keeps completed or partial
outputs. A paged index avoids claiming O(records) offsets are bounded memory.

Tac searches fixed separators backwards on opened regular files using 64 KiB
blocks and separator overlap; selected byte ranges are copied in blocks.
Storage is O(block + separator length), including a very long record. Standard
input, nonregular files and regex mode use an owned disk spool. No output for
that operand begins until its spool succeeds. A regular file's concurrent
mutation is not a snapshot guarantee. Regex mode retains O(input) memory in
addition to its spool because the shared matcher requires a contiguous byte
string with signed 32-bit indices. Preserve arbitrary separator spans and
nullable progress rather than silently restricting overlap. Lift this memory
limitation only with a shared matcher API over paged/seekable input and matching
Native/Wasm arbitrary-span, anchor, overlap and nullable-separator regressions.

Column consumes all operands once into a displayed-record snapshot, computes
global widths and then formats from that snapshot. Disk use is displayed bytes
plus sixteen bytes per retained record, across two temporary files. Memory
retains the longest record, global table-width vector and fixed I/O buffers.
Table and small-grid caches retain at most 1 MiB of record pages and 64 KiB of
index pages. Grid caches select sixteen to 256 pages from the output column
count to avoid thrashing interleaved cursors; their fixed upper limits are
16 MiB of record pages and 1 MiB of index pages, allocated only as read.
The first output follows the attempted input pass. Late input errors preserve
complete records and continue with later files; temporary-write failure aborts
before formatting.
An output error may leave an emitted prefix. Reopening mutable source files
for the second pass and retaining a complete output string were rejected.

Sort's `-S/--buffer-size` selects its accounted data budget, defaulting to
64 MiB; unsuffixed values use KiB. `-T/--temporary-directory` selects temporary
locations and may repeat. `--batch-size` selects the merge fan-in within the
implementation's maximum of sixteen inputs. Active/oversized records and
runtime allocation overhead remain separate from the budget, which is not an
RSS limit. Nonzero percentage buffer sizes reject before input/output effects; `0%`
uses the minimum budget without a capacity query. Released
public APIs do not expose physical-memory capacity. Lift this rejection only
when that query exists and percentage rounding, overflow and Native/Wasm
behavior are verified; guessed constants or a host child are not substitutes.

Csplit, column and tac's spooled modes require temporary-filesystem write
access. The catalog declares FileWrite for these commands as well as sort and
split. Spool directories are created exclusively and their files use mode
0600 where supported. Deferred cleanup owns only those invocation paths and
runs on success, ordinary failure and runtime-observable cancellation. Neither
SIGKILL nor a machine failure can guarantee unwinding. Package regressions and
registered command/policy cases target exact bytes, effects, long records and
wide-offset arithmetic; final resource observations and platform acceptance
must report the workloads actually run rather than infer a process RSS cap.

## Versions and evidence

The current core line scanner, command buffers and spools are checked by
package tests, `tests/cases/<command>.json` and shared stateful scenarios.
The 2026-10-24/25 changelog records their implementation and publication.
Use current Wasm and exact-MoonX checks; former two-backend observations
retain their dated scope and are not required delivery backends.

## Revisit when

Add locale profiles only when implementation and oracle evidence cover them; never rewrite the caller environment to hide a gap.

## Migrated text and binary profiles

The target remains each command's selected upstream behavior. Current
coordinates are in `tests/release_runner/current/latest.json`; package and
CLI assertions live alongside the implementation. These decisions do not
reinterpret accepted flags or certify every upstream option.

| Commands | Choice and reason | Rejected alternative and compatibility cost | Evidence and condition for expansion |
| --- | --- | --- | --- |
| rev, tac | Ordered operands; rev retains one ASCII/NUL record and tac reads fixed separators backwards with bounded block/overlap storage. Tac's GNU Emacs matcher preserves nullable progress. | Rev rejects non-ASCII records before output. Tac regex retains O(input) memory and a spool until a paged/seekable matcher interface is implemented and verified; neither command claims multibyte-locale decoding. | `rev.json`, `tac.json` and package regressions cover current source; pinned Linux O-stage observations and older releases remain distinct evidence. |
| expand, unexpand, fold | C-byte columns, explicit tab stops and control-byte rules; fold preserves input bytes and uses space breaks only when requested. Deterministic byte contracts require no terminal discovery. | Reject UTF-8 replacement decoding and assuming one code point occupies one display column. Non-C widths remain unimplemented; fold handles tabs/backspace/CR in column mode. | Their JSON contracts and fold package tests; expand locale claims only after wide/combining/malformed input and tab/control interactions pass the selected upstream oracle. |
| od, hexdump | Concatenate operands and preserve partial words, duplicate blocks and final offsets; the published O7 implementation adds the frozen Linux float ABI, strings/legacy offsets and custom hexdump format/color units. | No host delegation or inferred native ABI. Forward stdin skip is a documented read/discard extension; backward positioning needs a seekable input. | `od.json`, `hexdump.json`, numeric/format package tests and fixed-provider Native/Wasm development observations; PR/main and publication remain separate. |
| fmt | Width/goal paragraph optimization, crown/tagged margins and prefix selection with C-byte indentation and sentence spacing; no file rewrite. | Do not substitute fold or discard long words. Paragraph storage and non-C display widths remain separate work. | Current `fmt.json`, named regressions and O3 GNU margin/prefix/tab/EOF observations; PR/main and formal resources remain separate gates. |
| strings | Streaming C-byte scanning, GNU d/o/x offsets, last -o/-t selection, seven-column padding, TAB, filename prefixes, s/S encodings and selected output separators. | Reject b/l/B/L before input until wide decoding is implemented. No BFD/FFI or host fallback; locale/object sections remain project work. | Binutils 2.44 JSON and package contracts plus selected separator/cross-block development observations. Wide modes require endian/minimum-length/offset/invalid-input differentials. |
| column | Default vertical/-x grid and global -t layout use one indexed disk snapshot; retained caches and the current record replace whole-input/output buffers. | Temporary writes are required. GNU/Linux C-locale non-ASCII bytes are escaped; non-ASCII delimiters reject. Automatic terminal discovery and full Unicode widths remain separate capabilities. | Current spool/layout package regressions and command contracts; historical util-linux 2.40 evidence remains in the [repair summary](../../CHANGELOG.md#2026-10-11). Add terminal discovery only with public APIs and expand locale widths against versioned Unicode/locale data. |

The [changelog](../../CHANGELOG.md#2026-10-11) summarizes the original follow-up
audit; full observations remain in Git history.

`seq` streams without an arbitrary ten-million-record cutoff. Counting records
is unnecessary for separator placement; a boolean avoids both that semantic
limit and eventual counter overflow. Keep the explicit 4096-character numeric
operand bound and exponent/scale range -4096..4096 to bound BigInt allocation;
README/help and rejection contracts describe them. Arbitrary-precision input
growth remains project work, not async work. Remove these bounds only with
measured resource behavior and pre-output error tests; do not weaken normal
sequence output to enforce a test runner's budget.
The over-cap stress probe exposed the cost of two unbuffered writes per record.
Use the released public `io.BufferedWriter` with a 64 KiB buffer and an explicit
final flush. This bounds extra storage and preserves output bytes; partial
buffer visibility follows normal buffered CLI output. Per-record syscalls and
buffering the complete sequence were rejected. Retain the large-record-count
stress gate and ordinary separator/fraction/error contracts when changing this.
The second column review also compares controls and ANSI color sequences against
util-linux 2.40: table widths ignore complete control + `[` ... `m` sequences,
while the default grid retains its printable-character width rule. Output bytes
are preserved; this is not terminal detection or automatic color generation.
The [support record](../compatibility.md) tracks current profiles without
turning known defects into positive compatibility claims.

## Source review (2026-10-26)

Buffer/scanner and external-sort work is `1ffa967`; text options are `5dbe51d`/`2e867a3`; the snapshot/reverse-read changes are `87ca302`. Current sources: [stream.mbt](../../core/stream/stream.mbt), [sort](../../commands/sort/external.mbt), [csplit snapshot](../../commands/csplit/snapshot.mbt), [column spool](../../commands/column/spool.mbt), [tac](../../commands/tac/) and [rev](../../commands/rev/). Their package tests and JSON contracts retain the exact resource/error boundaries above.

## Further rg algorithm pilot (2026-10-28, not adopted)

Updated: 2026-10-28. This section exists in the temporary pilot checkout only.
The live workspace retains its previous lazy-metadata and bounded-count candidate.
The new candidate has not been committed, pushed, published or accepted through MoonX.

The experiment is `/private/tmp/cmd-rg-prefix-stream-20261028`. Its baseline is
the complete current working tree, including the earlier local changes, rather
than Git HEAD alone. `source.tar`, `baseline/`, `git-head.log` and `source-diff.log`
preserve that distinction. Every product artifact was built with the default
`moon build --target wasm --release`; no `moon-wasm-opt`, O3 pass, unsafe array
access or foreign-language product implementation was added. Local Moon commands
inherit `MOON_HOME="$HOME/.moon-accounts/cli"` and the existing PATH toolchain.

### Mechanisms and boundaries

1. A necessary byte-set prefix can exclude an entire block even when it is too
   frequent to serve as the main matcher. If it is present late, candidate-line
   discovery starts its existing inner-literal search there. An immediate first
   byte membership check avoids initializing SIMD for every short candidate line.
2. Oversized boolean searches use direct byte transition rows and four-step
   loops. An absorbing acceptance row allows one match check per group; line
   discovery replays a matching group once to recover the exact earliest endpoint.
   Captures, replacement expansion and greedy match endpoints retain their engine.
3. Eligible self loops search for their exact exit byte set using existing SIMD
   byte-set machinery. UTF-8 transition bytes remain in that set. Probing stops
   for a record when exits are frequent. Ordinary blocks keep the compact table.
4. Mandatory-literal rejection precedes plan construction. Empty matches, look
   assertions and over-budget plans retain the existing verification engine.
   The existing 256-state/65,536-cell construction limits remain; expanded byte
   rows add at most 257 KiB plus metadata. This is not a total-process memory bound.

These decisions are informed by the primary
[regex-automata prefilter contract](https://docs.rs/regex-automata/latest/regex_automata/util/prefilter/struct.Prefilter.html),
[DFA acceleration and alphabet configuration](https://docs.rs/regex-automata/latest/regex_automata/dfa/dense/struct.Config.html#method.accelerate),
and [The Rust Performance Book's bounds-check discussion](https://nnethercote.github.io/perf-book/bounds-checks.html).
The direct-byte loop actually removes the class lookup. Merely disabling Rust's
`byte_classes` setting would retain that lookup and is not the experiment here.
All array accesses in the pilot remain checked.

### Measured results and rejected variants

Complete-process wall times include startup, input, captured output and exit.
Each comparison has two windows, one warmup and nine measured samples per tool
per window, with rotating/reversed order. No sample removal or startup subtraction
was used. MAD/median must be at most 5%; between-window drift must be at most 10%.
All builds, tests, resource probes and subsequent diagnostics ran outside timing
windows. The frozen Rust executable is a local reference, not a sealed Linux
upstream parity profile.

Selected qualified results from `study-v2/review.json` compare this round's
starting candidate against `simd.wasm`:

| Workload | Baseline ms, two windows | Pilot ms, two windows | Time reduction |
| --- | --- | --- | --- |
| Frequent inner literal, absent required prefix | 52.574 / 53.388 | 22.579 / 23.034 | 56.9-57.1% |
| 8 MiB long record with late count hit | 116.914 / 117.015 | 32.226 / 32.293 | 72.4% |
| 8 MiB long record, count miss | 114.551 / 114.505 | 29.587 / 29.526 | 74.2% |
| Repeated-text long-record output, 8 MiB | 117.212 / 117.836 | 100.204 / 100.933 | 14.3-14.5% |
| Repeated-text long-record output, 64 MiB | 778.506 / 780.230 | 646.963 / 648.365 | 16.9% |
| Ordinary regex count, 64 MiB | 97.283 / 97.993 | 97.390 / 98.083 | Approximately unchanged |

The revised matrix contains 44 workloads and four tools: 176 preflights and
3,520 window invocations, all with equal status, stderr and complete stdout.
43/44 baseline-to-pilot comparisons qualify; the matching long-output row has
an unstable pilot window. Five Rust series are also unstable. Those observations
remain unqualified in the report; the independent protection run does not erase
them. Stable revised comparisons have no slowdown above 3%. The repeated-text
64 MiB output still takes 6.63-6.75 times the local Rust reference, so this is
not a claim of competitive performance across the matrix.

The initial `wide.wasm` variant regressed the frequent-exit no-match control
by about 12% because it constructed a table before a cheap rejection. The first
`accel.wasm` probe also cost more than the direct-byte loop on long records:
limiting exits to three bytes missed UTF-8 state exits. Neither variant is an
adoption candidate. The first prefix-only variant cost about 3.1% on short-prefix
output; the revised first-byte check reduces that observation to about 0.5%.
All initial windows remain in `comparison/` and `review.json`.

### Acceptance and resource status

- Strict Wasm check/build passed; all 1,648 Wasm tests passed. The functional
  suite has 2,117 passes, 19 platform skips and zero failures. Architecture
  validation covers 80 commands. Only the rg artifact differs from this round's
  baseline; the live workspace source and all its artifacts remain unchanged.
- The revised differential has 707 matching cases, including output-only,
  color, replacement, context, binary/CRLF, decoder and record-boundary controls.
  An earlier extended run timed out on the *baseline* with `-a -U -e '^'` and
  a roughly 1 MiB record. Its incomplete result is preserved in
  `study-v2/differential-timeout.json`. Large multiline controls other than the
  selected alternation use a bounded fixture in the subsequent run. The original
  baseline timeout remains unresolved and is not counted as a pass.
- The complete protection run registers ten added controls and covers 112
  workloads, including 58 rg workloads. 110/112 qualify, including 57/58 rg.
  `rg-null-long-output-8m` and the byte-identical `uniq-long-8m` control have
  unstable reference windows. The former also has a raw 6.04% second-window
  slowdown. The full timing verdict is **false**; no retry was used to turn it
  into a pass. See `gate-review.json` and `protection-simd/`.
- One stable small cost remains: `rg-dfa-long` changes from 54.566/54.936 ms to
  56.354/56.972 ms, a 3.28/3.71% slowdown. This is a measured cost, not noise.
  It is within the gate's 5% review boundary but is not accepted for mainline
  in this unadopted pilot. Investigate selection/construction cost on its
  approximately 1 MiB records before integration.
- Separate Darwin kernel peak-RSS observations cover seven workloads and three
  artifacts. For 64 MiB long-record counting, baseline and revised pilot peak
  at 164,970,496 and 165,216,256 bytes (157.33 and 157.56 MiB). Other pairs are
  similarly close. These single observations establish no memory reduction;
  full records are still retained. They are not formal resource acceptance.

### Next feasible experiments

The read-only structural probe in `diagnostics/minimize_probe_wbtest.mbt` does
not change a running matcher. For `[0-9]{4}.*Q|ZZ`, partition refinement reduces
21 reachable boolean states to 16. In the sampled post-prefix state it removes
all ten digit bytes from the exit set (141 exits become 131). This explains a
promising opportunity in repeated numeric text: equivalent boolean states still
cause avoidable transitions. It is structural evidence, not a timing result.

Try budgeted boolean DFA minimization before expanding byte rows, preserving
both immediate acceptance and EOF acceptance in the equivalence relation. Keep
it restricted to oversized boolean searches and measure construction separately.
[Rust's minimization documentation](https://docs.rs/regex-automata/latest/regex_automata/dfa/dense/struct.Config.html#method.minimize)
warns that construction can be expensive; do not assume smaller tables are faster.
The probe uses simple partition refinement and is not an implementation of
Hopcroft's production algorithm.

For memory, extend the existing literal-stream count protocol with a prepared
bounded DFA cursor. Eligibility must be established before discarding input;
unsupported assertions, empty matches, budgets, binary modes and explicit heap
limits must retain their existing path. Preserve decoder seams, EOF transitions,
record resets and read/output errors. Whole-line output needs retained or spooled
record bytes even after an early match; it cannot inherit count-only discarding.
This continuation architecture has not been implemented or measured in this pilot.

Integration remains conditional on resolving the recorded small cost, completing
the unstable protection coverage, registering reproducible fixture preparation,
and the repository's required three-platform development checks. Exact-version
MoonX and publication acceptance remain separate; rg is still unpublished.

## 2026-10-28 follow-up: bounded boolean minimization and broad exit sets

Updated: 2026-10-28.

### Scope and decision

This is a continuation in `/private/tmp/cmd-rg-minimize-20261028/pilot`.
The live workspace has not adopted either temporary pilot. All product changes,
tests and experiment runners remain pure MoonBit. Both new variants use the
default release Wasm artifact, with no manual O3 or other post-optimization pass.
The local result does not establish MoonX startup, three-platform development
acceptance, Linux upstream parity or publication acceptance.

The source baseline is the preceding pilot's frozen `final-pilot-source.tar`.
Artifact identities distinguish the experiments:

- `original.wasm`: live-workspace candidate,
  `84ddf070f75fea796ec9a87f8026a849f8f32a2f6faf4cf31350e9b9f49ad8c3`.
- `baseline.wasm`: preceding direct-row/SIMD pilot,
  `91dd1e2ac8582d6307f7bcf88708660aeec37140bb043dc1e24532f369b4e781`.
- `minimized.wasm`: bounded minimization,
  `4aaa0f840f062d2e900c391cf302656354f0c4d0bb493249db333a011462b72b`.
- `adaptive.wasm`: minimization plus broad exit-set eligibility,
  `18ac86ca5f840021582eed8c0074c08c305762938cf31f8b98324f3eb673999d`.

### Why these mechanisms help

The prior structural probe found that different DFA state identifiers can encode
equivalent future boolean behavior. Treating each identifier change as an exit
prevents SIMD from skipping repeated numeric text. The pilot refines partitions
using actual byte-class representatives, preserving immediate acceptance and EOF
acceptance separately. It then builds exit sets from the reduced direct-byte
rows. A cache retains the prepared plan for subsequent oversized records.

This is bounded Moore-style partition refinement, not Hopcroft's algorithm.
Construction stops after 32 rounds or 65,536 signature components; a declined
attempt returns the original table. It does not promise a minimal automaton when
the budget is exhausted. The existing 256-state, 65,536-cell and 512-NFA-state
eligibility limits remain. Short blocks retain their compact path, and mandatory
literal rejection still precedes construction. No captures, greedy endpoints,
empty matches, look assertions or unsupported paths change engines.

The next experiment changes one accelerator eligibility rule: permit any exact
exit set of 1 through 255 byte values, instead of rejecting sets above 192.
Set cardinality is not the same as exit frequency in the actual input. For
`[ab]{32}Q`, a state can have 254 possible exits while a homogeneous `a` record
contains almost none. Four ordinary transitions must return to the same state
before a probe; fewer than 32 skipped bytes disable further probing for that
record. The exit set includes every non-self transition, including UTF-8 bytes.

These choices draw on the primary
[regex-automata minimization documentation](https://docs.rs/regex-automata/latest/regex_automata/dfa/dense/struct.Config.html#method.minimize)
and [state-acceleration documentation](https://docs.rs/regex-automata/latest/regex_automata/dfa/dense/struct.Config.html#method.accelerate).
The former warns about expensive construction; the latter warns that frequent
exits can make acceleration slower. The bounded builder and measured runtime
disable policy address those distinct costs. The complexity advertised for
Rust's minimizer is not claimed for this bounded refinement implementation.

### Two staged timing experiments

Each stage uses two windows, one warmup and nine measured samples per tool per
window, complete process execution, unchanged deadlines and rotating/reversed
invocation order. MAD/median must be at most 5%, and between-window median drift
at most 10%. No filtering, startup subtraction or unchanged-candidate retry was
used. Builds, tests and resource observations run outside these windows.

Stage A compares 49 workloads across the preceding SIMD pilot, live candidate,
minimization pilot and frozen local Rust executable. All 147 Wasm series are
stable; five Rust series are unstable. All 196 preflights and 3,920 window
invocations have equal stdout, stderr and status. Every Wasm old/new comparison
qualifies, with no incremental slowdown above 3%. See `comparison/` and
`review.json`; the aggregate four-tool verdict remains false because it includes
the unstable Rust series.

For the 64 MiB repeated-text long record, minimization reduces output-mode
search from 644.643/648.058 ms to 70.310/71.222 ms. Count mode changes from
645.622/650.306 ms to 75.779/76.914 ms. The old `rg-dfa-long` small regression is
also reversed: its stage-A control changes from 55.142/55.851 ms in the previous
pilot to 25.502/25.802 ms, below the live candidate's 53.753/54.107 ms.

Stage B adds frequent and sparse exit controls, for 51 workloads and four tools.
All 153 Wasm series are stable; three Rust series are unstable (`output`,
`dense-regex`, `long-output-hit`). All 204 preflights and 4,080 window invocations
have equal stdout, stderr and status. Both incremental and cumulative Wasm pairs
qualify for all 51 workloads. The four-tool aggregate verdict remains false;
the three corresponding Rust ratios must not be used as accepted comparisons.
See `adaptive-study/comparison/` and `adaptive-study/review.json`.

| Workload | Live candidate ms | Minimized ms | Final adaptive ms |
| --- | --- | --- | --- |
| Long-record output search, 8 MiB | 117.750 / 118.009 | 29.155 / 29.234 | 29.305 / 29.234 |
| Long-record output search, 64 MiB | 783.951 / 782.359 | 70.319 / 70.735 | 70.457 / 70.881 |
| Long-record count, 64 MiB | 788.034 / 790.911 | 76.602 / 76.269 | 76.735 / 76.324 |
| Approximately 1 MiB records, default mode | 53.718 / 54.052 | 25.532 / 25.760 | 25.548 / 25.791 |
| `[ab]{32}Q`, homogeneous 8 MiB, late hit | 114.815 / 114.946 | 108.297 / 108.582 | 29.580 / 29.539 |
| Same pattern, exit every 4 KiB | 114.618 / 114.924 | 107.843 / 108.015 | 28.172 / 28.451 |
| Same pattern, exit every 40 bytes | 123.700 / 124.581 | 103.739 / 104.586 | 100.628 / 101.266 |
| Ordinary regex count, 64 MiB | 97.126 / 97.922 | 97.207 / 98.037 | 97.453 / 98.143 |

One stable incremental cost is retained separately: matching long-record output
changes from 34.048/33.177 ms to 33.699/34.294 ms, or -1.02%/+3.37%, between the
minimized and adaptive variants. It remains 71.2-72.0% faster than the live
candidate. This is not relabeled as noise or accepted for mainline by the pilot.
No incremental qualified cost exceeds the protection rule's 5% review boundary.

The final 64 MiB output search takes 0.731-0.744 times the local Rust duration;
count takes 0.779-0.796 times. These specific ratios are qualified. This is not
general Rust parity: empty input still takes 6.55-6.60 times Rust, the many-state
control 11.39-11.48 times, and frequent exits with a tail match about 7 times.

### Correctness and remaining acceptance

Strict Wasm check and full default-release build pass. All 1,652 Wasm tests pass;
the functional suite reports 2,117 passes, 19 platform skips and zero failures.
The architecture inventory covers all 80 commands. Only rg's artifact changes,
and this follow-up adds no generated-interface changes relative to the preceding
pilot.

New private tests traverse the reachable product machine of original and reduced
plans for ten patterns, checking every byte transition plus immediate and EOF
acceptance. This establishes all-finite-byte-string equivalence for those tested
machines, rather than relying only on sampled haystacks. Additional controls
exercise zero/tiny budgets, the 32-round limit, exact broad exit-set membership,
invalid bytes and compact/wide count agreement.

The revised differential contains 707 matching cases against the live candidate
and minimized variant. Its multiline fixture bounds are inherited from the
preceding experiment. The earlier baseline timeout on `-a -U -e '^'` over a long
record remains unresolved and is not counted as acceptance.

The full protection run compares the final adaptive artifact directly with the
live-workspace baseline frozen in the preceding experiment's `baseline/`, not
with the intermediate SIMD or minimized artifacts. The directory name
`protection-minimized/` covers the final `adaptive.wasm` identity listed above.
All 80 artifacts are inventoried and all changed artifacts have registered
coverage. Both complete windows and every result are preserved.

- 113/118 workloads qualify, including all 64/64 rg workloads. The full timing
  verdict is **false**, with no retry. See `gate-review.json` and
  `protection-minimized/`.
- One stable rg construction control has a small cumulative cost:
  `rg-min-constructor-many-states` changes from 150.658/152.042 ms to
  156.387/155.542 ms, or +3.80%/+2.30%. It meets the 5% review boundary but is
  not accepted for mainline in this temporary experiment. The independent
  51-case cumulative matrix has no cost above 3%; the maximum there is 2.56%.
  Both observations remain recorded rather than choosing the more favorable run.
- The five failed controls have byte-identical non-rg artifacts. `rev-long-8m`,
  `tac-stream-8m`, `tac-long-8m` and `uniq-long-8m` fail stability.
  `tac-file-8m` is stable by the declared criteria but has a +6.85% second-window
  cost. That measured threshold failure is not relabeled as noise. The unchanged
  `tac-multi-8m` control also has a +3.71% second-window cost, within the review
  boundary. These observations prevent a whole-suite passing claim.

Separate Darwin kernel peak-RSS observations cover seven workloads and three
artifacts after all timing windows. The live candidate and final adaptive pilot
peak at 164,937,728 and 165,036,032 bytes for 64 MiB long-record counting, or
157.30 and 157.39 MiB. The 8/20/32 MiB controls remain similarly close. These
single observations support no memory reduction and are not formal resource
acceptance. Complete records are still retained. See `resources/summary.json`.

### Feasibility and next priorities

The bounded minimizer and broader exact exit sets are feasible algorithmic
changes under the default MoonX delivery compilation profile. The measured
benefits require neither custom compiler flags nor an external implementation.
The prior 3-4% long-record control loss has been replaced by a substantial gain;
the remaining small costs above are explicit integration review items.

Before adoption, retain the two staged comparisons and the complete protection
failure, review the construction and matching-output costs, make fixture
preparation portable, and complete required development checks on Linux, macOS
and Windows. Exact-version MoonX validation remains a separate future step while
rg is unpublished. No temporary result authorizes publication.

The next architectural experiment should extend the existing count-stream
protocol with a prepared bounded DFA cursor. Establish eligibility before any
input is discarded; carry transition and acceptance state across input chunks,
then reset at each record boundary. Preserve decoder seams, EOF completion,
binary policies, count/invert/limit behavior and read/output failure ordering.
Unsupported modes must select their existing path before discarding bytes.
Whole-record output must retain or spool its bytes and cannot reuse count-only
discarding. This continuation path is proposed, not implemented or measured.

Separately profile the many-state fallback and empty-input startup. Raising the
global DFA budget is not justified by these results. Their remaining roughly
11x and 6.6x gaps to the local Rust reference make them better targets than
further tuning the already accelerated repeated-text scan.

`incremental-minimization.patch` applies to the preceding temporary pilot;
`cumulative-algorithm-pilot.patch` applies to the unchanged live working tree.
`benchmark-profiles.patch`, the pure MoonBit runners and complete evidence stay
in the experiment directory. Final sealing verifies all 80 live artifacts are
unchanged, all 80 temporary artifacts match the protected candidate, both patches
apply without modifying their targets, and the generated interfaces remain
unchanged relative to the preceding pilot. The final source and artifact hashes
are retained in `seal-hashes.log`.

## 2026-10-28 branch integration of the default-release rg pilot

Updated: 2026-10-28.

The user authorized integration and a normal push to the existing
`performance-optimization-and-cleanup` branch for three-platform development
checks. The cumulative product patch was applied to the live source after
saving its complete source, Git diff and all 80 default-release artifacts under
`/private/tmp/cmd-rg-delivery-20261028`. The earlier temporary-pilot sections
retain their historical scope and failed windows.

This branch accepts the measured +3.80%/+2.30% many-state construction control
and the minimization-to-adaptive -1.02%/+3.37% matching-output control as explicit
local tradeoffs for the large long-record gains. Neither is relabeled as noise.
The complete protection verdict remains false at 113/118, including all 64 rg
profiles within the declared gate; no unchanged timing run is repeated merely
to obtain a pass. CI correctness and the new cross-implementation comparison
are separate evidence.

All sixteen new protection profiles now have portable fixture generation in
`tests/benchmark/explore.mbtx`'s `prepare` mode. Reconstructed fixture bytes must
match the frozen pilot inputs before the branch is pushed. Required local
checks and all 80 default-release artifact identities are checked again after
integration. The expected rg SHA-256 remains
`18ac86ca5f840021582eed8c0074c08c305762938cf31f8b98324f3eb673999d`.

The command remains unpublished at its initial `0.1.0` coordinate. There is no
new option, support-profile or metadata contract, and no publication operation.
Required Linux, macOS and Windows results must bind to the pushed commit;
earlier green checks cannot establish acceptance of this source.

The integrated tree passes strict Wasm/product and Native/test-tool checks,
1,652 Wasm package tests, 118 Native test-tool regressions, and 2,117 functional
cases with 19 platform skips and zero failures. All 80 command artifacts match
the frozen final pilot; all nine distinct newly generated input files match its
recorded fixture bytes. The initial delivery inventory included the non-command
`core` build directory; the corrected inventory uses the frozen 80-command
manifest. No product or test failure was hidden by that inventory correction.
The architecture audit, interface generation, formatting and diff checks pass.

## 2026-10-29 search hotspot pilot (temporary checkout)

Updated: 2026-10-29. This section records a local pilot against commit
`0d65187615b3c67b71d986ef4b26d41cdb2c675f`. The live checkout and remote branch
are unchanged. No publication, integration or new three-platform CI acceptance
is claimed. All executable measurements use default release Wasm, without a
manual O3 pass or startup subtraction.

### Scope and mechanisms

- grep batches complete, unadorned records inside its existing immutable input
  chunk. Adjacent selected records share a contiguous copy and a batch flush.
  Prefixes, context and only-matching output retain their existing paths;
  incomplete records retain the existing cross-chunk assembler. Binary decisions
  remain in the refill path. Input/output failure ordering and short writes are
  covered by injected-reader/writer tests.
- rg's shortest-match adapter requests `earliest=true`. Candidate-line discovery
  requests it only when a configured terminator cannot occur in the match. Full
  span searches and captures retain their existing greedy semantics. This avoids
  scanning the rest of a long matching record after a bounded boolean plan has
  declined construction.
- grep's existing byte-record matcher recognizes a conservative anchored linear
  program: at most 256 instructions, a Begin assertion before consumption, no
  branches, references, word/line assertions or variable repetition. Boolean
  queries inspect bytes directly instead of converting each record to a String
  and entering the general span matcher. Whole-record and word-mode constraints
  retain their original fallback. No public API is added.

The rg decision follows the documented purpose of
[regex-automata earliest searches](https://docs.rs/regex-automata/latest/regex_automata/struct.Input.html#method.earliest).
The anchored specialization follows the broader engine-selection lesson of
[Rust's one-pass DFA](https://docs.rs/regex-automata/latest/regex_automata/dfa/onepass/struct.DFA.html):
recognize a restricted deterministic workload before using a general engine.
This pilot is a smaller branch-free interpreter, not an implementation of the
Rust one-pass DFA or its capture support.

### Staged evidence

The immutable baseline, sources, runners and raw samples are under
`/private/tmp/cmd-search-hotspots-20261029`. `v1` contains record-output batching
and rg early termination; `v2` additionally contains anchored byte predicates.
Each stage uses two windows of one warmup plus nine alternating old/new pairs,
20-second invocation deadlines, complete output/status comparison, MAD/median
at most 5% and window drift at most 10%.

`timing-v1-isolated` qualifies all 28 workloads. Relative to the starting source,
grep fixed-string output takes 68.60–69.54% less time, dense anchored-regex output
25.06–25.68% less, and sparse output 26.80–28.55% less. rg's many-state long-record
count takes 82.86–82.92% less time. Stable costs are retained separately: grep
numbered output +3.18/+3.20%, context +4.30/+4.39%, many-state count +4.39/+3.12%,
and empty input +3.33/+4.30%.

`timing-v2-v1` qualifies all 14 grep controls. Relative to v1, dense output takes
85.00–85.55% less time and its same-pattern count 87.21–87.35% less. Sparse output
and count take about 72% less; context takes 47.25–48.04% less. Fixed-string
output has a +3.63/-0.11% staged cost. These are measured costs, not discarded
samples or a claim that every workload improves.

The initially overlapped timing attempt was stopped and retained in `timing-v1`;
`timing-v1-invalid.txt` explains the concurrent functional run. It supplies no
qualified timing evidence. Full-protection setup failures are also retained:
missing Git metadata in the archive checkout, deprecated fixture APIs emitting
warnings into JSON, and missing architecture fixtures. They happened before any
full-protection timing window. The pilot fixes the deprecated API calls and
documents the separate `prepare-architecture` step.

### Correctness, resources and cumulative gate

The first stage passes all 1,657 Wasm tests and the complete functional suite
(2,117 passes, 19 platform skips). The final code passes 1,659 Wasm tests,
including 60,918 generated anchored/fallback comparisons against the general
span engine. A subsequent grep/rg functional run passes 124 checks with one
platform skip. Strict Wasm checking, interface generation, formatting and the
80-module/124-package architecture audit pass. Generated interfaces are unchanged.
The 80-command inventory changes only grep and rg; the other 78 artifacts remain
byte-identical. Fourteen additional grep profiles are registered.

`protection-v2-all` completes both windows for all 132 registered profiles.
Every measured invocation preserves stdout, stderr and exit status. The complete
timing verdict is **false: 129/132 pass**, with **81/82 grep/rg profiles passing**.
No qualified profile exceeds the 5% slowdown boundary. The failing observations
are retained without retry:

- `grep-hotspot-invert`: candidate window-two MAD/median is 9.13%. Its large
  apparent cumulative gain is unqualified, despite both staged experiments
  qualifying this workload.
- `ln-symbolic-validation`: unchanged candidate window-two MAD/median is 6.27%.
- `paste-8m`: unchanged reference medians drift by 14.89% between windows.

Stable cumulative results, against the starting commit:

| Workload | Baseline ms, two windows | Candidate ms, two windows | Elapsed reduction |
| --- | --- | --- | --- |
| grep fixed-string output, 8 MiB | 98.58 / 98.59 | 29.74 / 30.15 | 69.41–69.83% |
| grep dense anchored-regex output, 8 MiB | 289.84 / 289.99 | 31.57 / 32.21 | 88.89–89.11% |
| grep same dense regex, count | 214.95 / 215.38 | 27.64 / 27.98 | 87.01–87.14% |
| grep sparse anchored output, 8 MiB | 114.22 / 113.48 | 23.32 / 23.38 | 79.39–79.58% |
| rg many-state long-record count, 8 MiB | 154.03 / 155.79 | 26.75 / 27.60 | 82.28–82.63% |

Retained cumulative timing costs are grep numbered output +4.52/+3.62%, grep
empty input +3.61/+4.67%, grep 8 MiB count-miss +3.72/+2.61%, and rg entropy
literal count +3.45/-0.29%. These are explicit pilot tradeoffs; this document
does not authorize acceptance or label them as noise.

`resources/summary.json` contains three separate Darwin kernel peak-RSS
observations per workload and variant, using `/usr/bin/time -l` around moonrun.
grep dense output changes from 40.08–40.39 MiB to 43.02–43.09 MiB (approximately
3 MiB additional peak memory). rg many-state count remains 48.70–48.94 MiB and
64 MiB long-regex count remains 157.38–157.47 MiB across variants. This is not a
memory optimization. These changes create no product temporary files; injected
output failures still stop without retrying a partially written batch.

The pilot remains separate from the live branch. The failing cumulative timing
gate, small stable costs and grep memory increase must remain visible in an
integration decision. Correctness results from this local macOS run do not
establish Linux, Windows, exact-version MoonX or publication acceptance.

### Remaining feasible directions

1. Extend anchored byte execution to deterministic branches/repetition only when
   ambiguity can be rejected during bounded construction. Retain C-locale byte
   semantics, backreferences and leftmost-longest span extraction. Add held-out
   patterns and construction/short-input controls before broadening eligibility.
2. For rg, measure compilation, boolean-plan construction, scanning and Wasm
   startup separately. A bounded early-match probe may avoid constructing an
   unnecessary eager plan; it must not treat a probe boundary as EOF or invent
   assertion matches. Do not raise the DFA state cap without a cost model.
   Rust's [hybrid cache efficiency controls](https://docs.rs/regex-automata/latest/regex_automata/hybrid/dfa/struct.Config.html#method.minimum_bytes_per_state)
   illustrate measuring bytes processed per constructed state rather than
   treating more cached states as automatically faster.
3. General-regex count-only streaming needs a resumable automaton whose eligibility
   is settled before discarding bytes. Carry state, pending-record acceptance and
   decoder/EOF context across chunks. Preserve binary/error ordering and reject
   unsupported assertions before consumption. Existing literal streaming is a
   starting point, not evidence that arbitrary regex counting is already bounded.
4. For misses, attribute time to binary detection, delimiter scans and substring
   filtering before changing buffering. Avoid counting skipped delimiters when
   line metadata is unobservable, and examine prepared finders. A fused scan or
   larger read window must preserve visible output preceding binary detection.
   Neither this pilot nor the earlier long-record work removes full-record
   retention for general regexes.

## 2026-10-29 follow-up: deterministic anchors and resumable regex counts

### Scope and bounded mechanisms

This follow-up starts from the preceding temporary pilot's frozen `v2`
artifacts, not from the live branch. Its laboratory is
`/private/tmp/cmd-search-followup-20261029`. Every measurement uses default
release Wasm without manual O3. The previous pilot's failed cumulative gate and
its costs remain historical evidence; this follow-up does not erase them.

grep's Boolean record matcher now recognizes anchored deterministic repetition
and alternatives after the existing branch-free and ordinary DFA paths. Every
epsilon closure must have at most one consuming instruction for each byte.
Preparation rejects more than 256 NFA instructions, ambiguous choices,
backreferences and unsupported assertions. The dense table has at most 65,536
cells, with separate ordinary and real-EOF acceptance. Full span extraction,
captures, word/whole-record constraints and leftmost-longest behavior retain the
existing engine. This follows the restricted-search approach documented by
[Rust's one-pass DFA](https://docs.rs/regex-automata/latest/regex_automata/dfa/onepass/struct.DFA.html),
but implements only the Boolean byte-record subset, not Rust's capture engine.

rg gains a resumable cursor for its existing bounded Boolean plan. The driver
proves that matches exclude the record delimiter; assertions, empty matches and
construction-budget exhaustion decline the path before any bytes are discarded.
The searcher selects ordinary count-only text mode, without context, inversion,
multiline, statistics, stop/limit semantics or an explicit heap limit. A cheap
driver policy declines a required-literal filter whose shortest alternative is
longer than one byte, before any probe read. Eligible inputs fill the original line buffer at its ordinary
capacity (256 KiB for the CLI count sink). Only an unterminated full buffer
without an early Boolean match in its first 64 KiB attempts a streaming plan.
A match against that truncated prefix only declines optimization: it never
supplies a count. On decline, complete decoded records already in the original
buffer are processed before another read can fail. There is no replay wrapper,
second begin event, decoding pass or read after an observed EOF. Accepted
cursors reuse the same fixed-capacity input buffer.

The cursor retains DFA state and pending-record status across fixed-capacity
reads. Delimiters and actual EOF finalize records; chunk boundaries do not.
This follows the explicit
[end-of-input transition contract](https://docs.rs/regex-automata/latest/regex_automata/dfa/trait.Automaton.html#tymethod.next_eoi_state).
Read failure does not finalize an unterminated record. Complete records already
counted remain counted. Mandatory-literal filtering applies only to complete
fresh records, and exit-set acceleration remains active across chunk phases.
The optimization currently requires the first record to be long: a short header
followed by a long record still takes the old path. Early-matching long records
also retain it. Ordinary output and general regex search still retain complete
records; this is not a universal bounded-memory matcher.

### Rejected variants and resource observations

The unconditional `stream` variant reduces 64 MiB long-record count time by
48.26–49.11%, but stably slows ordinary regex misses by 9.84–10.48% and empty
input by 10.94–12.17%. It is rejected. The decoded-probe `adaptive` variant fixes
those costs but changes read alignment and regresses sparse accelerator exits
by 40.74–41.38%. The cause is treating the shortened distance from a chunk start
to its first exit as evidence of dense exits. The `phase` revision ignores that
truncated density observation. Four additional controls vary exit period and
phase; all qualify, with 9.15–19.53% reductions. The original sparse control
improves by 10.49–10.74%. These failed variants and their complete timing windows
are retained rather than retried or filtered.

An independent grep experiment borrowed the final contiguous output run instead
of copying it into the batch. Its 22-workload comparison qualifies only 18 rows,
does not establish an output speed benefit, and raises dense-output peak RSS
from 42.83–42.91 MiB to 43.89–43.98 MiB. It is reverted. The earlier batching
implementation is retained, including its previously documented memory cost.

The `phase` rg variant also raises the many-state early-hit control from about
49 MiB to 55 MiB by attempting an unnecessary bounded plan before fallback.
The intermediate `probe-match` revision declines that preparation after an early probe
match. Three separate Darwin kernel peak-RSS observations per side show:

| Workload | Previous pilot | Follow-up candidate |
| --- | --- | --- |
| grep dense output, 8 MiB | 42.73–43.00 MiB | 42.80–42.98 MiB |
| rg many-state early-hit count, 8 MiB | 48.75–48.89 MiB | 48.83–49.00 MiB |
| rg late/missing regex count, 64 MiB | 157.36–157.72 MiB | 32.33–32.39 MiB |

These observations use `/usr/bin/time -l` around moonrun, separate from timing
windows. They are local macOS process peaks, not Linux/Windows resource or MoonX
acceptance. No new temporary product files are created.

The first complete protection run, `protection-final`, exposes two additional
qualified regressions that the narrower stages missed: late-prefix counting
+25.86/+25.47%, and frequent-exit misses +53.57/+53.34%. Its whole verdict is
false: 139/154 pass, including 96/104 grep/rg profiles; thirteen other profiles
are unstable. The guarded revision returns prefetched records to the original
line buffer and retains whole-record multi-byte mandatory-literal rejection.
However, performing its cheap policy check only after searching the probe still
costs 12.65/12.81% on frequent-exit misses. That stage is also rejected.

The `preflight` revision moves the policy check before reading and bounds the
early-match inspection at 64 KiB while retaining the original read capacity.
All eighteen targeted controls qualify in two windows. Late-prefix count costs
+0.44/+0.57%, frequent-exit misses +0.51/+0.50%, and its corresponding hit
+1.53/+1.74%. The 64 MiB long-record count retains a 47.12% time reduction.
This explicitly gives up the intermediate streaming gain on the expensive
multi-byte-literal hit case in order to preserve its much cheaper miss path.
The policy is structural, not a list of benchmark pattern strings. Broader
streaming eligibility requires a correct cross-chunk mandatory-literal design
and renewed hit/miss measurements.

Final `resources-preflight` observations retain 32.25–32.47 MiB for the 64 MiB
count (baseline 157.39–157.69 MiB), and 48.78–48.89 MiB for the early-hit control
(baseline 48.75 MiB in all three observations). grep's unchanged one-pass
artifact ranges from 43.23–45.14 MiB, against 43.25–43.80 MiB for the baseline in
this collection. The higher observation is retained; this pilot makes no grep
memory-improvement claim and does not replace the raw resource ranges with the
earlier narrower sample.

### Final validation and unresolved acceptance boundary

`protection-preflight` compares all 80 artifacts and completes both windows for
154 registered workloads. Only grep and rg differ from the preceding pilot;
the other 78 artifacts are byte-identical. Every measured stdout, stderr and
exit status agrees. The timing verdict remains **false: 144/154 pass**, including
**98/104 grep/rg profiles**. This is a revised implementation, not a retry of the
failed `probe-match` candidate. Its earlier windows remain preserved.

Qualified improvements against the preceding frozen pilot are:

| Workload | Previous ms, two windows | Candidate ms, two windows | Elapsed reduction |
| --- | --- | --- | --- |
| grep anchored repetition count, 8 MiB | 229.71 / 231.21 | 28.04 / 28.76 | 87.56–87.79% |
| grep deterministic anchored branch output, 8 MiB | 241.29 / 241.46 | 36.21 / 33.13 | 85.00–86.28% |
| grep deterministic expression with end anchor, 8 MiB | 681.62 / 683.51 | 46.27 / 47.31 | 93.08–93.21% |
| rg text regex count, 8 MiB long record | 30.56 / 31.30 | 26.54 / 27.46 | 12.26–13.16% |
| rg text regex count, 20 MiB long record | 42.08 / 42.96 | 29.71 / 30.43 | 29.17–29.39% |
| rg text regex count, 32 MiB long record | 50.86 / 51.56 | 32.53 / 33.58 | 34.88–36.04% |
| rg text regex count, 64 MiB long record | 76.82 / 78.58 | 39.94 / 41.54 | 47.14–48.02% |

The earlier 25% and 53% regressions are resolved: late-prefix counting is
+0.04/+1.71%, and frequent-exit misses +0.98/+1.30% in this complete run.
However, two grep controls exceed the 5% boundary while satisfying stability:
`grep-hotspot-dense` is +6.51/+2.62%, and `grep-hotspot-invert` is +5.03/+1.46%.
The one-pass candidate is therefore **not accepted for integration**. Its large
targeted gains do not waive these losses. These controls use the preceding
anchored-linear path; attribution to dispatch/code generation versus output
cost needs a separate diagnostic, not an unsupported claim that the results
are noise. The unchanged `tac-multi-8m` artifact also fails at +5.32/+0.26%.

The seven unstable profiles are `ln-symbolic-validation`,
`grep-onepass-repeat`, `rg-output-dense-regex-8m`, `rg-line-buffered-1m`,
`rg-null-long-output-8m`, `rev-8m` and `uniq-long-8m`. Their apparent gains or
losses are not qualified. Smaller stable costs remain visible:
`rg-min-dfa-long-text` +3.63/+3.46%, and unchanged `rev-long-8m` +0.16/+4.45%.
No final rg profile has a qualified slowdown above 5%, but its unstable output
controls still prevent complete rg timing acceptance.

The final code passes 1,666 Wasm tests, including deterministic-program
comparisons, fragmented LF/NUL records, decoded BOM input, actual EOF versus
probe/chunk boundaries, begin denial and read failures after complete records.
The complete functional suite passes 2,117 checks with 19 platform skips and
zero failures. Strict Wasm checking, interface generation, formatting and the
80-module/124-package architecture audit pass. Core's public interface is
unchanged; four internal matcher/regex declarations are added. Source and
artifacts are sealed separately from the live branch. These local results do
not establish three-platform CI, exact-version MoonX or publication acceptance.

### Further experiments, not accepted implementations

Before integrating grep, isolate the remaining anchored-linear output costs
with allocation/dispatch observations and unchanged-artifact controls. Preserve
this failed verdict; a new timing window needs an identified change or a stated
diagnostic purpose, not an attempt to obtain a passing number.

1. Move count-mode long-record detection into the record reader so that a long
   record after a short header can activate a cursor. Preserve already consumed
   complete records, pending bytes, one begin event and the original read-error
   ordering. The present first-record restriction is an implementation boundary,
   not a regex or language limit. Start with the existing text/count eligibility;
   binary reporting and output modes need separate designs.
   Separately investigate cross-chunk mandatory-literal filtering. An absent
   literal in the current chunk does not justify discarding the regex prefix
   state: the literal may arrive in a later chunk. Preserve that state and
   partial literal suffixes before attempting wider eligibility.
2. Attribute default-mode misses to NUL detection, delimiter discovery and
   mandatory-literal searching before fusing scans. `LineBuffer::fill` currently
   performs binary and delimiter scans separately; grep also scans the input
   chunk and individual records. A fused path must retain the first binary-byte
   offset and any earlier observable output. [Prepared per-pattern finders](https://docs.rs/memchr/latest/memchr/memmem/struct.Finder.html) should
   be compared with the existing byte-search mechanisms, including repeated-byte
   collisions and high-entropy input, rather than added as an unmeasured layer.
3. Measure plan construction separately from scanning before broadening the
   streaming eligibility. The rejected early-hit allocation demonstrates that
   a bounded plan can still be unnecessary. Compare a bounded probe, existing
   early search and construction work per input byte; Rust's
   [hybrid DFA efficiency control](https://docs.rs/regex-automata/latest/regex_automata/hybrid/dfa/struct.Config.html#method.minimum_bytes_per_state)
   is a useful model for cost-aware fallback, not a reason to raise state caps.
   Alphabet compression of grep's new dense table is another candidate, but it
   adds a lookup to every byte and needs construction/short-input controls.
4. Investigate output allocation lifetimes before another borrowing experiment.
   The rejected slice variant is evidence that eliminating a source-level copy
   does not by itself establish lower peak memory or elapsed time in this target.
   Preserve the original partial-write and deferred-flush contracts and measure
   both allocation/peak memory and complete-process output throughput.

## 2026-10-29 selected search integration

The authorized integration selects the first pilot's grep whole-record output
batching and fixed-length branch-free anchored predicates, plus rg's early
Boolean termination and the follow-up `preflight` streaming counter. The
deterministic repetition/alternative one-pass experiment is excluded because
its qualified dense/inverted-output costs exceeded the 5% boundary. Its source,
patch and failed windows remain in the separate pilot evidence. The borrowed
output experiment and superseded streaming policies are also excluded.

All 80 artifacts were rebuilt and frozen before applying the selected source.
The integrated grep Wasm is byte-identical to first-pilot `v2`; integrated rg
is byte-identical to follow-up `preflight`; the other 78 artifacts are unchanged
from commit `0d65187615b3c67b71d986ef4b26d41cdb2c675f`. This avoids inferring
the selected behavior from a mixed experimental source tree. The eight anchored
profiles originally registered for one-pass exploration remain as fallback
controls, although that implementation is not included.

Local strict Wasm and Native-tool checks pass, as do 1,664 release-Wasm tests,
118 Native test-tool regressions, the complete functional suite (2,117 passes,
19 platform skips, zero failures), interface generation, formatting and the
80-module/124-package architecture audit. Core's public interface is unchanged;
the internal matcher/regex interface additions are intentional. Product code
and fixtures remain pure MoonBit and use default release Wasm, without an
additional optimization pass. No versions, registry coordinates or frozen
published expectations change. Required remote development CI is verified
separately on the pushed commit; this selection is not publication or exact-
version MoonX acceptance.

The new integration evidence is under
`/private/tmp/cmd-search-integration-20261029`. Its cumulative timing comparison
uses the pre-integration commit's frozen artifacts, rather than either temporary
pilot as the denominator. Historical whole-suite failures and recorded resource
costs remain valid within their dated scopes.

The cumulative integration run completes both windows for all 154 profiles,
with matching stdout, stderr and exit status throughout. Its timing verdict is
**false: 141/154 pass**, including **99/104 grep/rg profiles**. Every qualified
profile is within the 5% slowdown boundary. The thirteen failures are stability
failures: `ln-symbolic-validation`, `grep-onepass-empty`,
`rg-output-dense-regex-8m`, `rg-text-dense-regex-8m`, `rg-null-long-output-8m`,
`rg-pilot-long-output-hit`, `rev-8m`, `rev-long-8m`, `tac-stream-8m`,
`tac-file-8m`, `tac-long-8m`, `tac-multi-8m` and `column-table-8m`.
Their observations are preserved without declaring a passing whole-suite
performance result. The one-pass-named empty control exercises the unchanged
fallback implementation in this selected source.

Qualified cumulative time reductions include grep fixed output 68.68–69.58%,
dense anchored output 89.06–89.11%, the same-pattern count 87.07–87.10%, inverted
output 82.09–82.19%, and rg's eligible 64 MiB text regex count 47.41–49.07%.
The integration retains these measured small costs separately from instability:

| Control | First-window cost | Second-window cost |
| --- | --- | --- |
| rg long text DFA | +3.41% | +3.17% |
| grep short literal set | +3.20% | +0.86% |
| grep numbered output | +4.01% | +4.57% |
| grep many-state regex | +3.29% | +2.59% |
| grep empty input | +3.35% | +4.70% |
| grep 8 MiB miss | +3.67% | +3.51% |

These are retained tradeoffs in the authorized subset integration, not zero-cost
claims. The earlier grep output-batch peak-memory increase also remains visible
in the first-pilot resource evidence. Because the selected binaries match their
frozen variants, no new resource improvement is inferred from this integration.
