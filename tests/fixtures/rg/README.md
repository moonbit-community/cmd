# rg regression fixtures

The repository owns the large imported regex corpus and ignore-file fixtures.
Run the Wasm package tests from this checkout; the small internal test adapter
loads these files relative to the `cli/rg` module working directory. These
fixtures are required: missing, malformed, duplicate or truncated corpus data
fails the tests. Standalone registry archives do not contain this repository
integration corpus. Only test imports reach the corpus adapter.

`regex-corpus.jsonl` contains all 751 cases previously generated as
`commands/rg/internal/regex/internal/testdata/cases.mbt`. Names, patterns, input
bytes, capture spans, compile expectations, bounds and flags are unchanged.
The migration compared every field against the compiled original constants
before removing that source. Each line is one case; input bytes use hexadecimal.
Options retain MoonBit's standard `ToJson` representation: `null` for `None`
and a one-element array for `Some`, including optional capture spans. This
representation preserves absent captures separately from empty matches.

The corpus came from the regex crate's MIT/Apache-2.0 test corpus through the
pinned rg import documented in [upstream baselines](../../../docs/upstream-baselines.md).
The original source comment named `scripts/gen_regex_tests.py`; that generator
is not part of this repository. This migration preserves existing expectations
and provenance; it is not a new upstream comparison or a generator rewrite.

PikeVM, lazy DFA and meta-regex tests still consume the same corpus. Their
existing exclusions remain explicit in the drivers, including regex-lite,
custom line terminators and anchored meta searches. Keeping all 751 records
does not claim every engine executes every record.

The two files in `ignore/` preserve their original bytes, including the BOM.
Their former command-local paths were missing at migration time; the files
were recovered from repository commit `987cf02fc203b91b32e99dcd76da0802291bf454`
into this shared fixture location. The pattern fixture retains its upstream
attribution inside the file.

The 44 CLI-equivalent printer checks are regular entries in
[`tests/cases/rg.json`](../../cases/rg.json) and the shared runtime registry.
Their original `rg_compat_*` names remain case aliases. They retain exact
expected output and now also check process status and stderr. These are
contract expectations carried from the imported printer suite, not freshly
sealed ripgrep comparison results. The remaining 20 injected printer checks,
ordinary printer unit tests, flag white-box tests, Unicode data and engine
state regressions stay beside their implementations.
