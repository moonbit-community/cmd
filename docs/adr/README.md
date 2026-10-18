# Architecture Decisions

These are the active decisions that define the command surface. Read the
shortest applicable record first, then use [`compatibility.md`](../compatibility.md)
for the measured option profile and
[`reports/README.md`](../reports/README.md) for historical stage evidence.
Reports are archival context; they do not override the support record.

| ADR | Decision |
| --- | --- |
| [0001 Evidence First](0001-evidence.md) | Two drivers, shared testkit, pre-built artifacts and distinct contract/differential/boundary/availability evidence |
| [0002 Upper Layers Own Authorization](0002-policy.md) | Complete command environment; host authorization tested separately |
| [0003 Preserve Streams and Caller Locale](0003-streams.md) | Byte streams and partial effects; C locale belongs to fixtures |
| [0004 Portable Filesystem Subset](0004-filesystem.md) | Maximum strict Native/Wasm metadata, link, copy, and timestamp subset |
| [0005 HTTP Transfer Profile](0005-transfer.md) | Pure MoonBit bounded curl/wget HTTP behavior |
| [0006 Direct Child Processes](0006-process.md) | Explicit policy-visible children and local-only timeout |
| [0007 Shell Sessions and Make Scheduling](0007-language.md) | Persistent line REPL and concurrent dependency scheduling in MoonBit |
| [0008 Data and Language Algorithms](0008-data.md) | JSON bindings, byte regex, hashes, diff, gzip and UTC calendar profiles |
| [0009 Honest Failure and Upstream Side Effects](0009-safety.md) | Reject unsafe unsupported operations; preserve supported partial effects |

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

## Recent command decision coverage

Updated: 2026-10-12. All **31** command additions from the recent three batches
are mapped below. The canonical sections record target, choice/reason, rejected
alternatives, cost, version/evidence and reopening condition. This index is not
a second set of ADRs. New findings for column/strings/which/date are recorded as
defects or deviations, not retroactively approved design choices. See the
[prioritized follow-ups](../command-followups.md) for all 79 commands.

| Command | Canonical decision | Release |
| --- | --- | --- |
| base32 | [0008](0008-data.md#migrated-algorithm-profiles): RFC 4648/GNU padding and partial errors | 0.1.1 |
| cksum | [0008](0008-data.md#migrated-algorithm-profiles): POSIX CRC, defer algorithm/tag modes | 0.1.1 |
| expand | [0003](0003-streams.md#migrated-text-and-binary-profiles): byte columns/tab stops | 0.1.1 |
| mktemp | [0004](0004-filesystem.md#migrated-filesystem-profiles): random exclusive creation | 0.1.1 |
| realpath | [0004](0004-filesystem.md#migrated-filesystem-profiles): existing paths vs lexical/missing modes | 0.1.1 |
| rev | [0003](0003-streams.md#migrated-text-and-binary-profiles): byte reversal, one-file scope | 0.1.1 |
| tac | [0003](0003-streams.md#migrated-text-and-binary-profiles): fixed separators, project regex/multi-file work | 0.1.1 |
| tree | [0004](0004-filesystem.md#migrated-filesystem-profiles): ordinary trees, link preflight | 0.1.1 |
| unexpand | [0003](0003-streams.md#migrated-text-and-binary-profiles): leading/all byte blanks | 0.1.1 |
| unlink | [0004](0004-filesystem.md#migrated-filesystem-profiles): nofollow removal and extra-operand deviation | 0.1.1 |
| yes | [0006](0006-process.md#migrated-process-adjacent-profiles): bounded producer and pipe closure | 0.1.1 |
| fold | [0003](0003-streams.md#migrated-text-and-binary-profiles): byte/control columns and spaces | 0.1.0 |
| od | [0003](0003-streams.md#migrated-text-and-binary-profiles): integer layout/endian profile | 0.1.0 |
| hexdump | [0003](0003-streams.md#migrated-text-and-binary-profiles): formats, seekability and endian | 0.1.0 |
| md5sum | [0008](0008-data.md#migrated-algorithm-profiles): public incremental crypto/check records | 0.1.0 |
| sha1sum | [0008](0008-data.md#migrated-algorithm-profiles): public incremental crypto/check records | 0.1.0 |
| sha512sum | [0008](0008-data.md#migrated-algorithm-profiles): public incremental crypto/check records | 0.1.0 |
| sed | [0008](0008-data.md#migrated-algorithm-profiles): shared regex/stateful grammar; [0004](0004-filesystem.md) for writeback | 0.1.0 |
| diff | [0008](0008-data.md#migrated-algorithm-profiles): edit trace, bytes, timestamps and memory | 0.1.0 |
| patch | [0004](0004-filesystem.md#migrated-filesystem-profiles): inode/mode; [0009](0009-safety.md): exact hunks/partial effects | 0.1.0 |
| split | [0004](0004-filesystem.md#migrated-filesystem-profiles): exclusive outputs, suffixes and buffering | 0.1.0 |
| csplit | [0004](0004-filesystem.md#migrated-filesystem-profiles): exclusive outputs/owned cleanup; [0008](0008-data.md) regex | 0.1.0 |
| expr | [0008](0008-data.md#migrated-algorithm-profiles): BigInt and short-circuit byte regex | 0.1.0 |
| fmt | [0003](0003-streams.md#migrated-text-and-binary-profiles): paragraphs/goal/margins | 0.1.0 |
| gzip | [0008](0008-data.md#migrated-algorithm-profiles): public encoder/pure inflater, including the unpublished async 0.22.5 limited LZ/fixed profile; [0004](0004-filesystem.md) metadata | 0.1.0 |
| gunzip | [0008](0008-data.md#migrated-algorithm-profiles): member/CRC decoding; [0009](0009-safety.md) prefix-on-error | 0.1.0 |
| zcat | [0008](0008-data.md#migrated-algorithm-profiles): gzip-only stdout; [0009](0009-safety.md) prefix-on-error | 0.1.0 |
| column | [0003](0003-streams.md#migrated-text-and-binary-profiles): buffered tables and known default/LF defects | 0.1.0 |
| date | [0008](0008-data.md#migrated-algorithm-profiles): UTC calendar profile vs caller timezone | 0.1.0 |
| strings | [0003](0003-streams.md#migrated-text-and-binary-profiles): scanning vs known flag defects | 0.1.0 |
| which | [0006](0006-process.md#migrated-process-adjacent-profiles): PATH and public access-check correction | 0.1.0 |
