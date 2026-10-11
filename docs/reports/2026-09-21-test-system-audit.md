# Test-system audit and cleanup recommendations

Date: 2026-09-21. Scope: the then-unpublished 0.2.0 workspace, including
uncommitted implementation. README synchronization, structural review and
targeted runner execution were completed. No tests were removed, runners
refactored or CI reduced in this audit. Reorganization below was a proposal.
Language revision: 2026-10-11; historical results retained.

## Conclusion

Maintenance cost is concentrated in duplicate blackbox infrastructure, scattered
behavior definitions and integration tests organized by historical phase.
There were only 132 MoonBit test declarations for 48 commands; that count alone
does not show excessive unit testing. First unify execution and classification,
then bring valuable missing scenarios into the gates.

This review performed static inspection and targeted published-entrypoint calls
on macOS. It did not rerun full regression, Linux Docker or Windows, or measure
CI wall time. Duplicate execution has call-chain evidence; savings require
measurements.

## Inventory

| Layer | Size/location at the time | Purpose and limits |
| --- | --- | --- |
| MoonBit package tests | 29 files under commands/core/tests; 132 test/async test declarations | Algorithms, parsing, public API and some process integration; declarations are not backend execution counts |
| Workspace runner | compat.mbt 3,886 lines; main.mbt 994; policy.mbt 1,040 | Hardcoded compat, JSON oracle, host authorization tests |
| Active oracle data | tests/fixtures/runner/cases.json: 1,923 lines, 176 cases, 48 commands | Neither compat's sole source nor a complete new-regression index |
| Release runner | 1,533 non-test MoonBit lines | Exact MoonX versions with separate schema/fixture/snapshot/HTTP/report code |
| Release manifests | 47 packages each in historical and candidate manifests; 94 selected candidate cases | 0.2.0 validation-only; frozen base supports old-release replay |
| Separate probes | fidelity 247 lines, REPL 84, HTTP 232 | Important new behavior, absent from workflow |
| Host policies | Nine policy JSON files | Independent allow/deny checks, not semantic certification |

Counts came from rg, wc and JSON inspection. Historical report scripts/logs and
frozen fixtures are not counted as duplicate active tests.

## Classification and coverage defects

1. **Normal uncompared smoke always fails.** The case for
   `moonx cli/true@0.1.5` printed unverified_smoke and exited 1 even though
   package execution succeeded. Classification at release_runner/main.mbt:389
   and summary at line 601 conflicted with scheduled three-platform smoke.
   Separate availability from semantic agreement; availability can pass its
   limited assertions while release parity requires a differential or explicit
   contract. Do not combine both under an ambiguous passed count.

   Evidence: [smoke.log](2026-09-21-test-system-evidence/smoke.log) and
   [probe.mbtx](2026-09-21-test-system-evidence/probe.mbtx). The probe creates a
   true-only historical manifest in /tmp without editing repository manifests.
   Build Native release, then run
   `moon run docs/reports/2026-09-21-test-system-evidence/probe.mbtx --target native`
   from the root. It includes macOS ls comparisons and asserts defects present
   at audit time; do not preserve those defects as product contracts after repair.

2. **Equal filesystem snapshots miss important differences.**
   runner/main.mbt:266 and release_runner/fixtures.mbt:114 capture path, kind
   and regular contents only. Symlinks have empty contents; modes, timestamps
   and hard-link identities are omitted. Different link targets or modes can
   therefore pass. Move relevant macOS stat/link assertions from fidelity.mbtx
   into regular acceptance. Fixed host observers may fill missing public
   measurement APIs on the test side; product implementation stays MoonBit.
   Missing measurement means unverified, not equal.

3. **New full-process regressions are absent from CI.** The workflow does not
   invoke fidelity.mbtx, interactive_probe.mbtx or verify_cli.mbtx. Session,
   CookieJar and make scheduler unit tests do not prove prompts while stdin
   stays open, foreground input handoff or CLI-to-wire behavior. Policy covers
   selected Wasm cases; oracle candidates run only on Native.

4. **Option coverage can count unselected cases.** manifest.mbt:271 searches
   all base.cases + extra_cases while execution uses selected_cases. An
   unselected case can satisfy coverage, and most supported_options lists are
   empty. Validate the selection and separately record definition, platform
   execution and semantic success. Candidate validation cannot establish that
   94 cases ran.

5. **Contract strength is inconsistent.** main.mbt:400 returns after status and
   optional token/newline/forbidden checks, bypassing oracle and snapshots.
   A shell error case accepts empty stderr because it only forbids two internal
   strings; a jqlog file case merely requires stdout containing 1. Brand-specific
   diagnostics can justify partial checks, but stable output needs full bytes
   and file contracts need effects. Reject semantic contracts without behavioral
   assertions.

6. **Documentation review exposes missed behavior.** Native
   `ls -H -1 link`, with a link to a directory containing inside, outputs
   `link\n`, status 0; local /bin/ls outputs `inside\n`, status 0.
   commands/ls/main.mbt:270 lacks the command-line-link-following branch.
   The README was made accurate; behavior was not fixed in this audit.
   Green tests do not remove this known defect, and macOS comparison is not
   pinned GNU certification. Make help now includes -j/-k/-W, confirmed by
   actual `moon run commands/make --target native -- --help`.

## Maintenance cleanup

| Evidence | Recommendation | Preserve |
| --- | --- | --- |
| CI runs compat, then compat --gnu-diff; nine GNU comparisons are appended at the end | Run base compat once and make GNU an independent group, or one combined Linux run | Host GNU and pinned Docker versions provide different evidence |
| Both runners implement hex/path/fixtures/snapshots/normalization/environment/HTTP | Move matching semantics into existing testkit; keep two thin launchers | Registry versus artifact failures; avoid one large mode-flag interface |
| compat mixes phase345, p2_p3, p5, p9; HTTP exceeds 1,000 lines | Split same-package text/filesystem/process/shell/network files and allow command/case selection | File splitting alone saves no runtime and needs no new package |
| base64 -w0 repeats across unit/compat/fidelity; make concurrency scripts repeat | Merge only same-layer, same-entrypoint, same-assertion duplication | Algorithm tests versus real CLI, Native versus Wasm remain distinct |
| compat/JSON/release extras/probes each own behavior fragments | Central per-command active contracts; release manifests reference stable IDs | Frozen published-0.1-base.json must not follow current behavior |
| No shared timeout; no per-oracle-case timeout; concurrency relies on 100ms sleeps | Deadline helpers with close/cancel/wait; ready/ack barriers | Longer sleeps must not mask scheduling bugs; persistent sessions still need drivers |
| Windows make tests return early; metadata assertions run only on macOS | Explicit skips and missing dimensions | A returned test function does not verify Windows concurrency or Linux metadata |

Do not prioritize deleting malformed-byte, partial-output/write, same-inode,
cancellation/reaping, persistent-stdin or failure-propagation tests. They defend
observed failures or directly affected paths. Historical evidence is not a
cleanup target.

## Practices from mature projects

Sources reviewed on 2026-09-21; use the organization, not Rust/Go runtimes.

| Project | Practice | Application here |
| --- | --- | --- |
| [uutils guide](https://github.com/uutils/coreutils/blob/main/DEVELOPMENT.md), [test entrypoint](https://github.com/uutils/coreutils/blob/main/tests/tests.rs) | Utility-based tests, selective execution, separate own/GNU suites, replaceable binary | Command selection and shared launch adapters; retain distinct oracle evidence |
| [Go cmd/go scripts](https://go.dev/src/cmd/go/testdata/script/README) | Case-owned fixtures, independent workdirs, selection, phase diagnostics and retained failures | Consolidate case data, --case and failed fixtures; readable text, hex for NUL/invalid UTF-8 |
| [ripgrep tests](https://github.com/BurntSushi/ripgrep/blob/master/tests/tests.rs), [helpers](https://github.com/BurntSushi/ripgrep/blob/master/tests/util.rs) | Binary/JSON/multiline/feature/regression groups, shared temp dirs and commands | MoonBit functions for network/interactive/stateful scenarios with shared cleanup/diagnostics |

Go scripts do not use the system shell, but reproducing a testscript language
would add a parser and semantics to maintain. Simple data cases plus MoonBit
scenario functions are preferable here.

## Proposed structure and sequence

Keep package logic/API tests, single-call CLI/effect contracts and multi-round
lifecycle scenarios. A small shared testkit and adapters select Native, Wasm or
exact MoonX. Oracle supplies expected behavior; policy remains host integration.

| Step | Deliverable | Acceptance |
| --- | --- | --- |
| Classification/visibility | Correct smoke, selected coverage, per-case status/time/skip/failure and integrate three probes | Neither promote unverified semantics nor fail healthy availability |
| Low-risk reuse | Shared fixtures/snapshots/timeouts/reports, split compat, remove duplicate Linux calls | Map every old assertion; preserve same-platform results or explain changes |
| Active contracts | Per-command data, filters, readable fixtures, coordinate/selection manifests | One active definition per CLI behavior; historical replay still works |
| Measured scheduling | Measure build/execution/failure-rerun time; reuse artifacts | Establish cost before changing frequency; preserve platform coverage |

Remove duplicate mechanisms and same-layer assertions, not an arbitrary test
percentage. Begin with testkit, compat organization and repeated Linux runs,
without simultaneously changing all case semantics and release rules.

## README synchronization

This round checked candidate versions/options/limits, corrected historical Wasm
headers, environment-whitelist descriptions and missing semantics, and aligned
test/root README entrypoints and scope. Future behavior changes must update
package README, actual help, shared catalog, canonical compatibility and tests;
tradeoffs update the same ADR number. Historical results remain dated, with
later reports explaining changes. Package README must directly describe current
behavior; evidence and platform boundaries belong in canonical records.
Explicitly distinguish candidates from published MoonX versions.
