# ADR-0003: Streams, Ownership and Bounded Search

Status: Accepted
Date: 2026-09-05
Updated: 2026-11-08

## Decision

Dependencies flow from command adaptation to domain implementation to shared
runtime mechanisms and algorithms. Keep one `cli/core` module. Introduce a
shared mechanism when two actual consumers need the same contract; validation
tools are legitimate consumers of catalog metadata. Keep command dialects,
traversal policy, error ordering and specialized loops with their owners.

Borrow mutable storage only within its valid synchronous scope. Records that
survive refills must own bytes or retain immutable backing storage. Commit each
output event once; a declined buffered admission has no effect, and a failed
write is never replayed during cleanup. Budgeted storage is not a process RSS cap.

Resource cleanup and output flushing have different cancellation contracts.
Directory removal and direct-child completion expose `nocancel` when their
implementations already guarantee it; temporary-file rollback is explicitly
protected. Ln/mv destination rollback remains cancellable: cancellation can
arrive after the link or rename committed, and restoring the old destination
then could discard the new result. Preserve both the moved bytes and backup;
the [mv cancellation regression](../../commands/mv/cancellation_wbtest.mbt)
injects cancellation immediately after rename. Buffered output flushes remain
cancellable under downstream backpressure. The affected rollback and output
functions acknowledge `cancellable_defer` locally;
shielding those writes could make a cancelled command wait indefinitely for a
reader. Keep all other warnings enabled. The atomic-commit cancellation test in
[fsops](../../core/fsops/fsops_test.mbt) requires removal of the staged file while
preserving the destination; the blocked-writer test in
[paste](../../commands/paste/output_wbtest.mbt) covers serial and parallel flush
cancellation. Reconsider shielding output only with a bounded completion
contract and equivalent cancellation regressions.

The `tac` command shields its spool cleanup callback through public
`async.protect_from_cancel`. The published core 0.9.0 interface declares directory
close cancellable, unlike the current workspace annotation. Requiring a
`nocancel` callback would therefore compile in the workspace but fail an
isolated packaged check. The command's protection preserves real temporary-file
cleanup after cancellation without forcing a core release; its cancellation
test includes a cancellable suspension before removal. Publication dry runs
must validate the extracted module against its published dependencies.
Sort likewise protects owned spool removal against the published core 0.9.1
interface. Its regression observes real disk runs before cancelling a blocked
writer, then requires owned directories absent and unowned files preserved.
Only cleanup is shielded; output backpressure remains cancellable.

## Package ownership

The shared shell owns interpretation for sh, make recipes and split filters.
Keep printf parsing, test expressions, here-document scanning and stream aliases
private to that package. Make-specific expansion, prerequisite planning and
jobserver token ownership remain in the make command. These are actual consumers
and existing domain boundaries, not a new generic command framework. Shell
captures retain raw bytes; merged child stdout/stderr use a single pipe, and
printf clears submitted output before awaiting the writer so cleanup cannot
replay a failed write. See [ADR-0007](0007-language.md) for finite language scope.
The target-size repair changes shared behavior and therefore requires core 0.9.3 plus
updated sh/make/split dependencies. Other command coordinates stay unchanged.
No timing cost or performance acceptance is established by source changes or
correctness receipts; changed artifacts remain subject to the protection registry.

Argument normalization belongs to each command. Consume option values and
respect `--` before expanding aliases; values and filenames that resemble an
implementation key must remain data. Reject private keys as raw options rather
than accidentally exposing adapter internals. The shared catalog's option
strings are semantic coverage identifiers, not a complete accepted-argv grammar.
The existing identifiers remain stable; exact public spellings, project aliases
and diagnostic limits are recorded in the
[support profile](../compatibility.md#extensions-and-diagnostics), command help
and READMEs. This clarification changes no core runtime/API and does not require
a core release. Reconsider the metadata representation only if a real consumer
needs a separately validated spelling grammar; do not derive acceptance from
catalog membership.

Ordinary usage errors retain command-specific upstream status contracts.
Capability refusals are distinct, as are committed bytes/effects before an
error. Local exact diagnostic assertions may use a documented narrower
upstream category comparison for host messages or help trailers; neither
generic text nor a nonzero status alone establishes correctness. The f17 cases
exercise the actual aliases, empty/invalid input, literal operands and option
values. Generated index/coverage records are definitions, not execution receipts.

| Package | Responsibility |
| --- | --- |
| cli / contracts | Argument parsing and diagnostics / capability records consumed by validation |
| platform / process | Honest capability queries / execution context and direct-child lifetime |
| fsops / fsops/mode | Shared filesystem preflight and octal mode parsing; command-local ordered effects |
| fswalk | Directory handles and requested observations; callers own sorting, pruning and links |
| stream / tempio | Record and output ownership / exclusive temporary storage and range copying |
| bytesearch / bytere | Reusable byte kernels / C-byte regex semantics and bounded accelerators |
| checksum / checksum/cli | Incremental algorithms / command records, files and diagnostics |
| gzipops / gzipops/cli | Codec state and history / command options and execution |
| shell | Session and control-flow state; sh, make and split own orchestration |
| netops | Request, response, redirect and output responsibilities within one transfer path |
| numfmt / time_zone | Exact fixed-profile numeric formatting / checked timezone conversion |
| jq_filter | Public-AST adaptation preserving lexical bindings and assignment paths |
| quoting / tabstops | Byte quoting and parsed tab grids; callers retain their dialects |

Public APIs and generated data are not dead code merely because current runtime
consumers are absent. The [core migration table](../../core/README.md#090-api-changes)
records versioned API changes; published coordinates remain independent.

## Typst command adaptation

`commands/typst` owns the migrated CLI driver, document environment, font and
local-package discovery, and watcher. The engine remains the released external
`moonbitlang/typst@0.1.10` dependency. The upstream executable has no callable
public dispatcher, and its kit imports its own platform implementation; copying
only its main function cannot replace that dependency. Keep the necessary kit
packages private here, with a local pure MoonBit platform adapter. Do not copy
the evaluator, layout engine, exporters or embedded font assets into cmd, and
do not introduce a shared core API without a second actual consumer.

The synchronous engine's filesystem callbacks use released `moonbitlang/x/fs`
APIs. File and font reads can retain complete files. Explicit stdin is read once
through `moonbitlang/async/stdio` after argument validation and retained by the
document environment. The same public async API writes binary output and
propagates write failures to a nonzero exit. Metadata commands do not read stdin.
No command-owned FFI, native stub or unstable host declaration is used. External
dependencies may contain code for other targets; only their Wasm implementations
belong to this product's build.

Lexical canonicalization, path-based identity, unavailable terminal detection
and UTC local-time fallback remain explicit limitations. Symlink-aware root
containment is not established. Improve these only with a released synchronous
public API or a reviewed engine integration that supplies async observations
without breaking synchronous callbacks. Full recompilation preserves the
upstream watch model; no performance acceptance is claimed. Network package
downloads, viewer launching, self-update, completion generation, traces and
the HTML HTTP server remain rejected. Each capability needs an implementation
through public MoonBit APIs and registered regression evidence before enabling.

Preserve the migrated upstream tests and keep command-specific integration tests
private. Registered CLI evidence covers metadata, evaluation, imports, embedded
fonts, exact SVG, PDF file/stdout identity, PNG dimensions, page selection,
dependency output, broken output and watch recompilation. A separate PDF reader
checks exported page structure. Export and watch checks are independent
assertions; seven evaluation cases also pass pinned Typst 0.15.1 comparisons on
Linux. This does not establish full Rust Typst parity. The first release,
`cli/typst@0.1.0`, passed three-platform development checks and
[exact-coordinate MoonX acceptance](https://github.com/moonbit-community/cmd/actions/runs/41957907959).
Published watch tests stop the console group, wait for output-stream EOF and
require Windows working-directory release before reporting child cleanup.
Typst has an explicit untimed disposition;
future performance work requires genuine document/font workloads and a fresh
baseline containing all 81 command artifacts.

## Search ownership and execution

Rg's private driver owns search policy and the concrete matcher adapter.
Regex syntax and automata stay in `internal/regex`; reusable byte mechanisms
stay in `core/bytesearch`. Matcher and searcher cannot import driver, including
through tests. Adapter integration tests belong to driver; private buffer tests
use a searcher-local matcher.

Keep immutable plans separate from mutable buffers, caches and statistics.
Construction budgets, fast-path eligibility and profitability are distinct
decisions. Declined plans replay the original input through the ordinary engine
without duplicating sink begin or events. Short reads are not EOF. Counter
admission cannot depend on an early match or the record being first in a file.

## Input and output mechanisms

Use synchronous loops over already available records and bytes; suspend at
actual I/O boundaries. Coalesce output where it preserves visibility and error
order. Keep early-exit, context, line-buffered and partial-error behavior explicit.
Shared buffering does not require a universal command execution framework.

Base32/base64 encoding retains only unfinished quanta and wrap state between
bounded reads. Base32 decoding retains its whole-input read-error contract.
Rg releases exceptional reader buffers after success or error; active fallback
records and multiline inputs can still grow. See the current mechanisms in
[streams](../performance/streams.md), [search](../performance/search.md) and
[codecs](../performance/codecs.md).

## Streaming and temporary storage

Spool only when semantics require future input, reverse access or bounded
in-memory sorting. Own temporary names exclusively; close handles before removal,
preserve the primary error and report cleanup-only failure. Observable
cancellation requires cleanup, but SIGKILL and machine failure cannot guarantee it.

Sort budgets exclude oversized active records and runtime overhead. Tail retains
the requested suffix plus backing-chunk slack; a selected long record remains
unbounded. Tac regex retains contiguous input; split filter/path state grows
with visited pieces. Csplit and column use indexed disk snapshots with bounded
caches. Details and unlock conditions are in [streams](../performance/streams.md)
and [ordering](../performance/ordering.md).

## Known limits and tradeoffs

Current support boundaries remain in [compatibility.md](../compatibility.md).
In particular, wc regular-stdin padding needs descriptor metadata; tac retains
its overlapping-separator discrepancy; rg has no effective DFA byte-budget,
parallel search or mmap implementation. Accounted buffers do not bound all
record, matcher, child, path or output storage.

Accepted timing costs below are dated local decisions, not current universal
slowdowns or permission to waive a failed gate. Full measurements remain in the
[pre-consolidation record](https://github.com/moonbit-community/cmd/blob/c4ea7795b0eb6e6fd6d0dffa0e7709809569bbb1/docs/adr/0003-streams.md).

| Decision | Recorded cost and condition for reconsideration |
| --- | --- |
| Tail retained views; xargs streaming lifecycle | 2026-11-01: tail regular stdin 2.52–4.18%; final xargs UnicodeData 3.79–4.54%. Preserve lifetime/error assertions and remeasure all affected modes before changing ownership. Later xargs stability failure remains failed. |
| Sort batch/comparator phase | 2026-11-01: decimal-key 3.30–3.71% against its preceding phase. Later exact-decimal repairs supersede its implementation scope; retain integer, fractional and spill controls. |
| Earlier base32 byte-kernel phase | 2026-11-01: small binary input 1.36–1.57% in one phase and 2.80% in one cumulative window. Superseded by streaming encoding; these are historical costs, not present acceptance. |

Allocation tradeoffs and rejected experiments are explained alongside their
algorithms in [performance](../performance/README.md). Experimental packed-Huffman
and CRC costs are not adopted costs. Noise, RSS observations and throughput
measurements remain separate evidence categories.

## Pending cleanup decisions

| Proposal | Current disposition and next condition |
| --- | --- |
| Share dump-reader loops (C01) | Keep owner-local loops: opening, zero limits, over-skip, rendering and finalization differ. A narrower allocation change needs short-read, EOF, budget and failed-write evidence. |
| Reduce core visibility (C02) | `teddy_max_literals`, `Algorithm::hex_length` and `gzipops/cli.help` remain public after a restored trial. Make an intentional API decision before changing them. |
| Remove published platform helpers (C02) | Local non-use of `is_cross_device_error`, `native_separator` and `accepts_separator` does not establish external non-use; choose a compatibility policy first. |
| Make `Session::finish` synchronous (C02) | Retain async: EOF now reparses pending source and may execute async `run_jobs`. The earlier synchronous trial predates this behavior and is no longer applicable. Reconsider only if command execution is deliberately moved to another async API while preserving EOF and adapter contracts. |

## Verification and reconsideration

Use [architecture validation](../../tests/tools/architecture.mbtx), private ownership
tests and independent CLI contracts. Strategy/source/test/workload bindings live
in [protection.json](../../tests/benchmark/protection.json); measurement gates
live in [PROTECTION.md](../../tests/benchmark/PROTECTION.md). New sharing must
preserve bytes, error order and real consumer contracts before timing.
Delivery and publication follow [ADR-0001](0001-evidence.md).
