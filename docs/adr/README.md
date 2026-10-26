# Architecture Decisions

Updated: 2026-10-26

These nine records define current implementation choices, alternatives,
compatibility costs and conditions for lifting limits. The
[support record](../compatibility.md) describes current command profiles;
[CHANGELOG.md](../../CHANGELOG.md) records dated delivery results. Neither
source inspection nor an old passing report establishes new acceptance.

| ADR | Current decision |
| --- | --- |
| [0001 Evidence](0001-evidence.md) | Shared Wasm/MoonX assertions, Native test tools, immutable Linux oracle and separate manual release/resource workflows |
| [0002 Authorization](0002-policy.md) | Host-owned authorization; complete environment; catalog requirements are descriptive |
| [0003 Streams](0003-streams.md) | Exact bytes and partial output, reusable buffers, bounded caches and explicit spool/whole-input costs |
| [0004 Filesystem](0004-filesystem.md) | Operation-specific metadata/identity limits; preserve aliases, modes and failure effects |
| [0005 Transfer](0005-transfer.md) | Public HTTP passthrough, owned framing and separate curl/Wget credential, retry and output profiles |
| [0006 Processes](0006-process.md) | Direct-child cancellation/wait/pipe ownership; no process-tree, exec or signal-sending substitution |
| [0007 Shell and make](0007-language.md) | Persistent pipe sessions, explicit grammar and dependency-ready concurrent scheduling |
| [0008 Algorithms](0008-data.md) | JSON adapters, parsed byte regex, numeric/checksum/DEFLATE algorithms, diff reconstruction and TZif |
| [0009 Failure effects](0009-safety.md) | Honest rejection, ordered partial success and operation-specific preflight |

## Current command decision coverage

There are 80 workspace commands: 78 published, unpublished rg and local-only
timeout. Published coordinates come from `tests/release_runner/current/latest.json`;
workspace versions come from each module. A historical migration version is
not a current release label. Core 0.8.2 is a catalog-only workspace candidate;
the published core is 0.8.1 and command dependency coordinates stay explicit.

| Command family | Primary records and current choices |
| --- | --- |
| Text filters, seq, fmt, expand/unexpand, od/hexdump/xxd, strings | 0003/0008: byte profiles, selected fixed-ABI formats and stream/error behavior |
| sort, rev, tac, split, csplit, column | 0003/0004: external runs, backward reads or indexed snapshots; no inferred RSS cap or safe overwrite |
| Path/mode/link/copy commands, ls/tree/find/test | 0004/0009: only publicly available metadata, operation-specific rejection and real platform effects |
| curl, wget | 0005: explicit wire profiles; 0004/0006 for path races and cancellation scope |
| env, xargs, yes, which, timeout | 0002/0006: environment, literal argv, independent confirmation and observable direct-child results |
| sh, make, split --filter | 0006/0007: public pipes and MoonBit Session/scheduler; no host-shell implementation |
| jq, jqlog, date, checksums, base32/base64 | 0008: public dependencies plus scoped adapters, formats and error effects |
| grep, sed, expr, csplit, tac | 0008/0003: shared C-byte matcher, capture semantics and explicit resource/locale limits |
| diff, patch | 0008/0004/0009: linear auxiliary reconstruction, offset/fuzz/rejects and mode-preserving writeback limits |
| gzip, gunzip, zcat | 0008/0009: pure streaming codecs and decoded-prefix failures; named replacement remains 0004 |
| rg | 0003/0004/0006/0008: pinned private algorithms, async I/O, direct-child preprocessing and deferred compression |

## Historical consolidation and source review

The former thirty records were consolidated on 2026-09-05: 0001 retained
evidence; 0002 absorbed policy parts of 0006/0024; 0003 absorbed
0002/0016/0017/0020/0025; 0004 absorbed 0003/0004/0010/0011/0013/0019/0029/0030;
0005 absorbed 0005/0021; 0006 absorbed process parts of 0006/0018/0022/0026;
0007 absorbed 0012/0015/0028; 0008 absorbed 0008/0009/0027; and 0009 absorbed
0014 plus safety parts of 0013/0029. Git retains the original text.

The 2026-10-26 refresh checked original implementation commits and current
source paths listed in each ADR. Removed reports, plans and migration indexes
remain readable at `65b4b7eea24c8215776c40721e1e00ad436268ce`, for example:

```text
git show 65b4b7eea24c8215776c40721e1e00ad436268ce:docs/adr/0008-data.md
```

Future changes update the affected decision and support profile together.
Preserve unresolved API/semantic limits and distinguish release evidence
from implementation, local observations and formal performance acceptance.
