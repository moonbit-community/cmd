# Text compatibility assertion migration

Date: 2026-09-21. Source: the pre-migration `tests/runner/compat_text.mbt`.
The migration preserves its assertions as command JSON contracts. The
`compat-text-line-N` identifier refers to the starting line of an old `expect`,
`expect_failure`, or `expect_stdout_contains` invocation, before this migration.
These identifiers are stable migration identifiers, not live source pointers.

Every extracted `expect` keeps its argv, stdin bytes, exact stdout and status.
Success cases now also require empty stderr. Decoder and argument errors keep
the old diagnostic fragment and exact status, require exact stdout, and explain
why stderr wording is only partially matched. Version/help assertions have been
strengthened to the published project text rather than a loose substring.
Binary/NUL input and output use hex; ordinary text remains readable.

The root migration merges staging contracts into the existing command files and
records aliases where an existing case already protects the same behavior. Both
Native and Wasm execute the resulting portable contracts. An existing oracle
case is not deleted merely because it now also has a local contract.

| Original assertion | Retained JSON ID(s) | Observation retained or strengthened |
| --- | --- | --- |
| `run_record_file_cases`: join unmatched rows and output list | `compat-text-join-output-list` | status, exact stdout/stderr, input files |
| cat/xxd and xargs limits; env NUL output; sh stdin positionals | Corresponding `compat-text-line-N` | argv, stdin, status, stdout; empty stderr added |
| include and command-line make variable precedence | `compat-text-make-include-cli-override` | same Makefile/include fixtures, exact output/status |
| cp preserve/touch date pre-creation refusal | `compat-text-cp-preserve-rejected`, `compat-text-touch-date-rejected` | explicit failure status, diagnostic, unchanged fixture including absent output |
| chmod reference capability refusal | `compat-text-chmod-reference-rejected` | status, diagnostic, unchanged fixture |
| `run_text_option_cases`: grep binary notice | `compat-text-grep-binary-stderr` | exact stderr, empty stdout, status |
| grep silent missing operand | `compat-text-grep-silent-missing` | status, empty stderr; empty stdout added |
| grep recursive include/exclude fixture | Corresponding `compat-text-line-N` | exact selected filename/record after fixture prefix and separator normalization |
| env help | `compat-text-env-help` | full usage text, status, empty stderr |
| sort disorder diagnosis | `compat-text-sort-check-diagnostic` | failure status, empty stdout, diagnostic fragment |
| wc aligned files and files0 list equivalence | `compat-text-wc-aligned-files`, `compat-text-wc-files0-accounting` | both invocations independently assert the same full expected accounting bytes |
| wc successful count before missing file | `compat-text-wc-partial-counts` | exact count/total stdout, failure status, missing diagnostic |
| remaining grep/env/sort/uniq/wc/head option checks | Corresponding `compat-text-line-N` | original argv, stdin, status and output/diagnostic, empty opposite stream |
| `run_edge_cases`: 64 KiB wc, invalid UTF-8 cut/uniq, NUL nl, base64 | Corresponding `compat-text-line-N` | full bytes and status; stderr assertion added |
| `run_argument_edge_cases`: base64/path/cat/cut/printf/seq/echo/paste/sleep/true/false/tr/nl | Corresponding `compat-text-line-N` | all prior independent invocations, with exact output/status and reasoned diagnostic contracts |
| jqlog final newline in help/parser failure | `compat-text-jqlog-help-newline`, `compat-text-jqlog-error-newline` | complete help/error bytes imply the original single trailing newline checks |
| cmp 0/1/2 status matrix | `compat-text-cmp-equal-status`, `compat-text-cmp-different-status`, `compat-text-cmp-error-status` | each case gets its own fixture, status, output and diagnostic |
| comm NUL and order-check precedence/default behavior | `compat-text-comm-nul-records`, `compat-text-comm-check-order`, `compat-text-comm-nocheck-precedence`, `compat-text-comm-default-order`, `compat-text-comm-pairable-unsorted` | all five invocations retained independently; full partial stdout included |
| paste/join NUL records | `compat-text-paste-nul-records`, `compat-text-join-nul-records` | exact binary output/status |
| join check/nocheck precedence | `compat-text-join-check-order`, `compat-text-join-nocheck-precedence` | separate fixtures, status, diagnostic and output |
| invalid logical PWD fallback | `compat-text-pwd-invalid-logical-fallback` | exact physical fixture path after normalization is stronger than merely excluding invalid PWD |
| printenv existing plus missing variable | `compat-text-printenv-present-missing` | partial stdout, status, empty stderr |
| sha256sum warn/strict/status/ignore-missing | `compat-text-sha256sum-warn-malformed`, `compat-text-sha256sum-strict-status`, `compat-text-sha256sum-ignore-missing` | each invocation retains files, status, streams and diagnostic |
| sha256sum binary/text precedence | `compat-text-sha256sum-last-text`, `compat-text-sha256sum-last-binary` | full digest and marker replace substring-only marker checks |
| mkdir error before successful later operand | `compat-text-mkdir-partial-order` | failure status plus created directory |
| rm missing before removable operand | `compat-text-rm-partial-order` | failure status plus removed file |
| rmdir nonempty before empty operand | `compat-text-rmdir-partial-order` | failure status, later removal, retained nonempty directory/content |
| tee failed sink followed by valid sink | `compat-text-tee-partial-output` | failure status, binary stdout and identical file contents |

Two functions remain as genuine process scenarios:

- `run_text_process_composition_cases` retains eight invocations: find spawning
  false and printf; xargs spawning printf for `-I`, `-L`, `-E`, and false for exit
  propagation; env spawning printenv under `-C`, and pwd under repeated `-C`.
  The built child executable and parent/child result relationship are part of
  the contract, so these are not replaced with a host utility in JSON.
- `run_sleep_cancel_case` retains cancellation and wait of a live sleep child.
  A single static invocation cannot express the external cancellation event.

`patterned_bytes` remains a fixture helper used by chunk-boundary scenarios.
No one-shot command expectations remain in these functions.
