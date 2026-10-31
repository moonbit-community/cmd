# Shared-foundation performance protection

## One active real-source inventory

`protect.mbtx` compares all 80 command artifacts against an immutable
baseline and rejects any changed command without qualifying real timing
coverage. It uses `real.json` schema 3 and its associated source and coverage
registries. The declared scope is 125 workloads across 40 timing commands and
three correctness-only commands, ln, make and sh. The 31 complete genuine
sources total 22,152,148 unique payload bytes, with a 16 MiB per-source cap and
a 64 MiB suite budget. Counts describe the inventory; they do not establish
execution or timing success.

`protection.json` binds strategy invariants to this inventory. The former
generated timing matrices and separate rg launcher are retired; new timing
does not accept schema 2. Synthetic adversarial fixtures remain private
command or test-tool correctness regressions. Historical definitions and
reports retain their dated scope, rather than becoming current acceptance.

Source, command artifacts, configuration, tools, runtime and actual input
identities are preserved and checked before and after execution. Unchanged
artifacts outside the declared scope need no new timing claim, and receive
none. A correctness-only disposition cannot qualify a changed artifact's
performance. Missing profiles, missing required rows or an empty required
selection fail closed.

The final `timing_passed` verdict requires the single inventory's independent
local correctness preflight, actual native calibration and complete old/new
timing windows. It retains `general_performance_acceptance: false`,
`upstream_parity: false` and `blind_holdout: false`. Neither a registry entry
nor an artifact comparison alone establishes correctness, timing, peak RSS or
publication acceptance.

## Prepare and run

Before changing shared production code, save the optimized source and every
baseline Wasm artifact. The baseline CLI root contains
`COMMAND/COMMAND.wasm` for all 80 commands. Preserve the independent
published expectations, source recovery state and failed reports. Use the
default release Wasm build without an extra manual optimization pass.

Prepare a fresh checked corpus using `prepare_real_corpora.mbtx` as described
in [README.md](README.md). Complete source identities and license records are
pinned by `tests/fixtures/benchmark/real-sources.json`; no source is repeated,
padded or replaced by generated size-budget data. Semantic codec encoding,
sorting/key projection and distinct-file copies are setup operations outside
timing.

Run from the repository root with the existing PATH toolchain, a checked
corpus and a fixed native reference directory containing gzip and all selected
timing-command references:

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/benchmark/prepare_real_corpora.mbtx -- \
  /absolute/new-corpus --download
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target wasm --release
MOON_HOME="$HOME/.moon-accounts/cli" \
  CMD_BENCH_CORPUS_ROOT=/absolute/prepared-corpus \
  CMD_BENCH_ORACLE_BIN=/absolute/native-oracle/bin \
  moon run tests/benchmark/protect.mbtx -- /absolute/frozen-baseline-cli /absolute/new-evidence
```

The launcher takes two arguments. Its former generated-fixture argument is
retired and rejected. It preserves the existing candidate artifacts, rebuilds
current release Wasm, checks product-source identities across that build,
validates the architecture inventory and rebuilds
the Native benchmark observer and local correctness driver in release mode
before the timing windows. These are test tools; product behavior still runs
through the frozen release Wasm artifacts. Serialize all workspace builds and
tests, then keep the host quiet throughout measurement. Do not overlap builds,
tests, other benchmarks or diagnostic observer interventions.

Use a fresh evidence directory per identified change. Never overwrite or
silently retry a failed window. Compare each adopted phase with its preceding
passing phase, then compare the final candidate cumulatively with the original
artifacts.

## Correctness and timing gates

Before timing, declared local cases execute against the same frozen candidate
Wasm with their independent exact or structured assertions. Case identity,
command ownership and platform applicability are checked. Scenario pass tags
and row counts alone cannot establish a functional boundary. These finite
local witnesses cover the declared EOF, error, filesystem and stateful
contracts; they provide no throughput claim.

Every real-source old/new comparison also receives native correctness
calibration outside measured A/B timing. Both artifacts must satisfy the
declared output/status/effect relation. Reference provenance remains a separate
upstream-parity requirement: a host executable hash is insufficient. GNU
`wc` uses the recorded `LC_ALL=C`, `POSIXLY_CORRECT=1` profile.

Each required real workload has a correctness pair and one warmup pair, then
nine alternating old/new pairs in each of two windows. The second window
reverses the initial order. Complete process time includes startup, input,
output, exit and direct-child teardown. There is no startup subtraction,
MoonX launch/cache measurement, sample filtering or automatic retry.

Both sides require finite positive durations and MAD/median at most 5% in
each window. Their two medians may differ by at most 10% of their mean. Each
row's candidate/baseline median ratio must be at most 1.05 in both windows.
Report qualified 3–5% losses individually and record accepted small costs in
ADR-0003; reject or revise a qualified loss above 5%. Gains elsewhere cannot
offset a loss. The separate formal `run` mode uses 105 pairs and its own
statistical policy; a protection pass is not a formal 105-pair result.

Status, stderr, complete output and declared filesystem effects remain
checked. Ordinary output uses bounded byte comparison. Declared tree relations
use a complete record multiset preserving multiplicity or full parsed JSON.
Gzip streams must independently decode to the genuine source; different valid
compressed streams are allowed. Split/csplit relations reconstruct the source.
Named inputs and directory collections preserve actual source bytes.

The same generic engine records regular-file input, fragmented stdin pipes
and slow-output sinks as distinct measured regimes. Producer write sizes do
not guarantee matching child read boundaries. HTTP workloads use genuine
source bytes: the local fixture enforces the declared request method and
complete upload body before responding. Only the assigned loopback address
is normalized; actual invocations remain in evidence.

## Preserve implementation boundaries

Architecture validation checks strategy ownership, source files, named
correctness tests, invariants and workload links. Missing sources or named
tests, duplicate IDs, unknown statuses and orphan links fail closed.
Implementation `Strategy:` markers and registrations are checked in both
directions. Validation establishes coverage links; it is not a substitute for
executing their contracts.

Keep specialized command loops, explicit borrowing, output-failure behavior,
temporary cleanup, dialects and error ordering. rg search policy and its
matcher adapter stay private to the driver; reusable byte mechanisms and
regex syntax/automata retain their own boundaries. Physical read-ahead,
logical decoding windows and formatted-output admission remain separate.
Preserve match extraction, replacement, context and statistics behavior before
admitting output.

Boolean search plans must retain candidate filtering through a block: an
initial dense region does not prove the remaining records should all use
the DFA. Keep private construction-budget, frequent/sparse exit, Unicode,
EOF, long-record and rejection regressions. Historical `grep-onepass-*`
names describe rejection controls, not an adopted general one-pass engine.
Preserve exact deferred table values and ordering, including help/version,
file-type listing and filtered-search behavior.

The oversized-record plan and its former 8/20/32/64 MiB synthetic controls are
algorithm and resource diagnostics. Their historical failures remain recorded
in ADR-0003; those generated sizes are excluded from the new bounded real-source
timing inventory. The previous `sort-spill-8m` deadline failure likewise
remains failed evidence. A separately validated repair cannot invent an old/new
speed ratio from a missing baseline or extend the acceptance deadline.

## Separate acceptance scopes

Run the applicable Wasm unit and functional suites, then inspect peak RSS and
temporary cleanup separately. Resource diagnostics retain their explicitly
dated input and observer scope; they do not become real-source timing
qualification. Additional manual `moon-wasm-opt -O3` diagnostics cannot qualify
the default MoonX delivery profile.

This local workflow does not run the required three-platform development CI,
publish packages, establish upstream parity or replace exact-version MoonX
acceptance. Registry and local-contract coverage remain finite; unsupported
or unmeasured modes stay explicit in `real-coverage.json`. Add real workloads
and independent boundary witnesses when a new fast path or affected command
requires them. Publication uses `moon publish` only.
