# Architecture Decisions

Updated: 2026-11-01

ADRs summarize current decisions, their reasons, consequences and conditions for
reconsideration. Update the existing decision when it changes.

| ADR | Decision |
| --- | --- |
| [0001 Validation](0001-evidence.md) | Separate Wasm correctness, upstream, resource and publication acceptance |
| [0002 Authorization](0002-policy.md) | The embedding host owns permissions |
| [0003 Streams and ownership](0003-streams.md) | Share mechanisms while keeping command policy and lifetimes explicit |
| [0004 Filesystem](0004-filesystem.md) | Implement the correct public-API subset with explicit expansion conditions |
| [0005 HTTP transfer](0005-transfer.md) | Own HTTP/1 framing and preserve distinct curl/Wget profiles |
| [0006 Processes](0006-process.md) | Own direct-child I/O, cancellation and waits |
| [0007 Shell and make](0007-language.md) | Preserve session state and dependency-ready scheduling |
| [0008 Algorithms](0008-data.md) | Preserve regex dialects, numeric ABI and codec/error contracts |
| [0009 Failure effects](0009-safety.md) | Preserve operation-specific partial effects and honest rejections |

## Documentation ownership

| Information | Authoritative location |
| --- | --- |
| Decisions, package responsibilities, accepted tradeoffs and API proposals | The applicable ADR; package dispositions remain in ADR-0003 |
| Current algorithms, call paths, invariants, complexity and useful rejected approaches | [Performance guide](../performance/README.md) |
| Dated delivery and release summaries | [CHANGELOG.md](../../CHANGELOG.md) |
| Options and support boundaries | Command READMEs and [compatibility.md](../compatibility.md) |
| Executable workload definitions and measurement rules | [Benchmark registry and guide](../../tests/benchmark/README.md) |
| Published coordinates and independent expectations | [Release manifest](../../tests/release/latest.json) |

Keep the changelog to a few outcome-oriented bullets per date. In algorithm
documents, update the current explanation rather than appending experiment
rounds. Retain a rejected approach only when its reason and retry condition
help a future implementation. Link exact test/workload owners instead of copying
their inventories. Measurements must identify their dated scope; failures and
partial evidence cannot become acceptance through summarization.

## History

Detailed reports and superseded decisions remain recoverable in Git:

- [Before the nine-record consolidation](https://github.com/moonbit-community/cmd/tree/65b4b7eea24c8215776c40721e1e00ad436268ce/docs/adr).
- [Before the 2026-10-30 simplification](https://github.com/moonbit-community/cmd/tree/6e7be831cc687386b4e4f62eaad6d4cf7a34318b/docs/adr).
- [Before this consolidation](https://github.com/moonbit-community/cmd/tree/c4ea7795b0eb6e6fd6d0dffa0e7709809569bbb1/docs/adr), including complete experiment outcomes and corrections.

Temporary host paths are not durable documentation links. Tests and owning
source establish current behavior; an ADR explains the decision, not exhaustive
compatibility or performance acceptance.
