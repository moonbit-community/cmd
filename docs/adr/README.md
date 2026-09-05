# Architecture Decisions

These are the active decisions that define the command surface. Read the
shortest applicable record first, then use [`compatibility.md`](../compatibility.md)
for the measured option profile and
[`reports/README.md`](../reports/README.md) for historical stage evidence.
Reports are archival context; they do not override the support record.

| ADR | Decision |
| --- | --- |
| [0001 Evidence First](0001-evidence.md) | One runner, three suites, pre-built artifacts, and evidence-based support claims |
| [0002 Harness Owns Policy](0002-policy.md) | Wasm authorization comes from the harness and is tested separately |
| [0003 Deterministic Streams](0003-streams.md) | Byte-clean stdin, C-locale records, bounded sort, and descriptor-follow tail |
| [0004 Portable Filesystem Subset](0004-filesystem.md) | Maximum strict Native/Wasm metadata, link, copy, and timestamp subset |
| [0005 HTTP Transfer Profile](0005-transfer.md) | Pure MoonBit bounded curl/wget HTTP behavior |
| [0006 Direct Child Processes](0006-process.md) | Explicit policy-visible children and local-only timeout |
| [0007 Interpreted Language Slices](0007-language.md) | Bounded MoonBit `sh` and `make`, with no host delegation |
| [0008 Bounded JSON Modes](0008-data.md) | Deterministic jq CLI modes and imported jqlog contract |
| [0009 Fail Before Mutation](0009-safety.md) | Preflight, source preservation, and no-side-effect rejection |

## Historical Consolidation

The former 30 records were descriptive fragments of these decisions. They are
removed from the active tree; git history retains the original text.

| Canonical ADR | Consolidates |
| --- | --- |
| 0001 | 0001 |
| 0002 | 0006 (policy portions), 0024 |
| 0003 | 0002, 0016, 0017, 0020, 0025 |
| 0004 | 0003, 0004, 0010, 0011, 0013, 0019, 0029, 0030 |
| 0005 | 0005, 0021 |
| 0006 | 0006 (child-execution portions), 0018, 0022, 0026 |
| 0007 | 0012, 0015, 0028 |
| 0008 | 0008, 0009, 0027 |
| 0009 | 0014 and safety portions of 0013/0029 |

Historical provenance and upstream version pins remain separate documents in
`docs/`; they are not duplicated as ADRs.
