# Performance Algorithms

Updated: 2026-11-01

This guide explains the current implementation: where work happens, which
inputs enter an optimized path, what storage it owns and why alternatives were
retained or rejected. It is organized by mechanism so a future change can update
one explanation and reuse the existing tests and workloads.

| Topic | Main questions |
| --- | --- |
| [Search](search.md) | Matcher selection, Boolean counting, replay, cache pressure and long records |
| [Streams and records](streams.md) | Batching, borrowed storage, output visibility, suffix windows and disk indexes |
| [Ordering and structured data](ordering.md) | Exact keys, external sort, diff reconstruction, joins and JSON framing |
| [Codecs and checksums](codecs.md) | Encoding quanta, DEFLATE token loops, history, CRC and failed table experiments |
| [Traversal and execution](execution.md) | Lazy observations, argument budgets, concurrent child slots and file copying |

## How to use and extend this guide

Start with the owning source and the command's support profile. Distinguish an
upstream idea, an implemented local mechanism, a measured result and a proposal.
Similar algorithms need not share dialects, failure effects or lifecycle rules.

For a new mechanism, explain its call path, admission rule, invariant, storage
cost and fallback. Link the independent regressions and existing real workload
IDs. Keep a short rejected-approach note only when it records a useful reason
and a condition for trying again. Update the current topic in place; add a new
topic only for a separate family of mechanisms.

[ADR-0003](../adr/0003-streams.md) owns package responsibilities, accepted tradeoffs
and API proposals. [CHANGELOG.md](../../CHANGELOG.md) owns dated delivery summaries.
The [benchmark guide](../../tests/benchmark/README.md) and
[protection protocol](../../tests/benchmark/PROTECTION.md) own measurement rules.
Do not create another runner, workload registry or chronological report archive.
Source/test/workload bindings are executable in
[protection.json](../../tests/benchmark/protection.json), checked by
[architecture.mbtx](../../tests/tools/architecture.mbtx).

## Evidence and limits

The 2026-11-01 `c4ea779` checkpoint has passing three-platform development CI.
Its local macOS cumulative timing comparison qualifies **165/171** registered
rows, including base32, rg, cp and the newly timed ln/test operations.
Full performance protection remains failed: two wc padding cases and the fmt
book case fail exact native comparison; two cat rows and xargs options fail
stability. None is normalized, excluded or converted into a pass here.

Topic-level observations retain their exact workload, baseline and platform
scope. Genuine-source timing is startup-inclusive; synthetic resource probes
establish neither throughput nor a process RSS bound. Ordinary pushes run
development correctness, not manual resource or publication acceptance.

Complete measurements, accepted small costs, unsuccessful variants and source
identities remain in the immutable
[pre-consolidation ADR](https://github.com/moonbit-community/cmd/blob/c4ea7795b0eb6e6fd6d0dffa0e7709809569bbb1/docs/adr/0003-streams.md)
and [changelog](https://github.com/moonbit-community/cmd/blob/c4ea7795b0eb6e6fd6d0dffa0e7709809569bbb1/CHANGELOG.md).
Earlier search experiments remain in the linked history there. These records
are recovery routes, not evidence that an old experiment is currently adopted.

For the next optimization, freeze the current source and artifacts, run local
contracts before timing, and use the existing complete genuine sources. An
unchanged failed window stays failed; gains on one mode cannot compensate for
regressions or missing coverage on another. Reopen a rejected approach only
after an identified implementation, capability or measurement-condition change.
