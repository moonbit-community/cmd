# Registered package test reports

This native harness turns individual registered MoonBit tests into standard
`CaseReport` rows. The selected test may execute on Native, Wasm, or both with
`--backend pair`. It reads
`tests/registry/registry.json`, validates source bindings, and uses the exact
`package-test:<file>::<name>` behavior ID in each row.

Run from the workspace root with the developer account inherited by child
Moon invocations:

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/packages/run.mbtx -- \
  --backend native \
  --case 'package-test:tests/registry/registry_wbtest.mbt::registry rejects duplicate behavior IDs' \
  --report-dir test-reports/package-registry-native

MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/packages/run.mbtx -- \
  --backend wasm --package core/jq_filter \
  --report-dir test-reports/package-jq-filter-wasm
```

Exactly one of `--all`, `--case` and `--package` is required. `--all` selects
registered tests supporting the requested backend; with `--backend pair` it
selects only supported dual-backend contracts requiring comparison, excluding
Native-only harness tests. Declared platform exclusions are also omitted from
`--all` selection; an explicit excluded `--case` still returns a skip and fails
to supply semantic evidence. For example:

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/packages/run.mbtx -- \
  --backend pair --all --report-dir test-reports/package-pairs
```

The package selector is an
exact repository-relative package directory, not a recursive prefix. A new
report directory is required for every invocation. The adapter runs selected
tests serially, so do not run it concurrently with workspace build, check,
test, info, or format operations. Each build and test invocation has a
120-second deadline; timeout or cleanup uncertainty produces infrastructure
failure evidence.

For each applicable registry binding the adapter first uses `moon test
--build-only` on its source file. It reads the generated test-info JSON, finds
exactly one matching source name, and invokes that file with `--index`. This
preserves names containing filter metacharacters. A pass requires exit status
zero and exactly one summary reading `Total tests: 1, passed: 1, failed: 0.`
in the captured streams. Zero tests, multiple tests, missing or changed
summary formats, attributed/skipped tests, and ambiguous indices cannot
produce semantic pass rows. The adapter currently rejects all compiler test
attributes until their execution semantics are explicitly supported.

Backend restrictions and explicit platform exceptions in the registry produce
`skip` rows before compilation or execution. Skips are not semantic evidence,
and the invocation returns nonzero if any selected row is not a pass. The
adapter records only the `status` observation established by the named test
assertions; it does not pretend that the package runner's stdout is a command
stdout assertion. Additional registry observations remain missing until an
adapter explicitly proves them.

Each report contains `summary.jsonl`, `summary.md`, and `run-metadata.json`.
Per-case evidence retains build and test invocation arguments, complete raw
stdout/stderr streams, status/timeout/cleanup records, the compiled test-info
JSON, and the exact test artifact's SHA-256. Frozen test executables live under
`artifacts/<backend>/`; the run metadata hashes those bytes. An artifact or
index change between compilation and execution invalidates the row.

`source-corpus.json` records SHA-256 fingerprints of workspace MoonBit sources,
Moon module/package declarations, JSON test inputs and registry documents,
plus `moon.work`. The adapter recomputes that corpus after testing; any
mutation invalidates every row. The canonical registry fingerprint serves as
the run manifest hash. Git, live toolchain, host, environment, and execution
timestamps use the shared testkit metadata collector. Missing metadata keeps
reproducibility partial and makes the invocation fail.

For a change-coverage audit supply the report's metadata, the registry as its
manifest, and the report's source-corpus ledger:

```text
--run-metadata test-reports/package-registry-native/run-metadata.json \
--manifest tests/registry/registry.json \
--case-corpus test-reports/package-registry-native/source-corpus.json
```

Package reports are execution evidence for exact registered tests. They do
not establish that a test covers an unrelated changed behavior or upgrade
package assertions to upstream differential compatibility.

Pair mode runs the same exact named test on both backends and retains separate
captures. Each side must complete exactly one passing test before the adapter
compares the actual process exit status and complete stdout/stderr bytes.
Different printed observations fail even if both assertion sets pass. The
adapter emits the two contract rows plus a `native+wasm` backend-pair row.
The registered package observation remains `status`: captured test-driver
streams are comparison evidence, not command-output assertions. There is no
conversion of unrelated passing package summaries into a paired result.
This scoped comparison does not observe every internal value inside an
assertion-only test. Both targets execute the exact registered assertions, and
the pair compares only exposed process observations. Richer registry dimensions
remain missing and fail the row; metadata, JSON and stateful scenario pairs
provide the command-output and filesystem comparisons.
