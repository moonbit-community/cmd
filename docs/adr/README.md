# Architecture Decisions

Updated: 2026-10-30

These records describe current ownership, technical choices, compatibility
costs and conditions for changing them. Command options and supported profiles
belong in [compatibility.md](../compatibility.md) and command READMEs;
dated changes and releases belong in [CHANGELOG.md](../../CHANGELOG.md).

| ADR | Decision |
| --- | --- |
| [0001 Validation](0001-evidence.md) | Wasm correctness on three platforms; independent upstream, resource and published-coordinate acceptance |
| [0002 Authorization](0002-policy.md) | The embedding host owns permissions; catalog metadata only describes requirements |
| [0003 Streams and ownership](0003-streams.md) | Preserve bytes and error order; share mechanisms while keeping command policy local |
| [0004 Filesystem](0004-filesystem.md) | Implement the correct public-API subset without guessing identity, mode or link effects |
| [0005 HTTP transfer](0005-transfer.md) | Own HTTP/1 framing and keep curl/Wget credential, retry and output profiles distinct |
| [0006 Processes](0006-process.md) | Own direct-child pipes, cancellation and waits without claiming process-tree control |
| [0007 Shell and make](0007-language.md) | Pure MoonBit sessions and dependency-ready scheduling with explicit grammar limits |
| [0008 Algorithms](0008-data.md) | Preserve regex dialects, numeric ABI and codec/error contracts |
| [0009 Failure effects](0009-safety.md) | Report unsupported operations honestly and preserve operation-specific partial effects |

## Scope and authorities

The workspace contains 80 commands. The published inventory contains 78;
rg is an unpublished candidate and timeout remains local-only. Exact published
coordinates, including core 0.8.2, are defined by
[latest.json](../../tests/release_runner/current/latest.json). Workspace source
changes do not update those published packages or their frozen expectations.

Tests and implementation are the executable authorities. An ADR explains why
a choice exists; it does not certify every input or convert a historical local
measurement into current acceptance. Shared package dispositions and pending
cleanup decisions are maintained in ADR-0003, without a second report tree.

## Historical records

The nine-record structure replaced thirty records on 2026-09-05. Full reports,
intermediate experiments and failed measurements remain in Git:

- [Before the 2026-10-26 consolidation](https://github.com/moonbit-community/cmd/tree/65b4b7eea24c8215776c40721e1e00ad436268ce/docs/adr).
- [Before the 2026-10-30 simplification](https://github.com/moonbit-community/cmd/tree/6e7be831cc687386b4e4f62eaad6d4cf7a34318b/docs/adr),
  including the complete cleanup audit and candidate probes.

Update an existing decision when its implementation or boundary changes.
Keep the reason, consequence, remaining limitation and verification route;
do not append an execution diary. Temporary build paths are not durable
documentation references.
