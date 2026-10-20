# Command implementation and release roadmap

Updated: 2026-10-20

This is the accepted implementation sequence for the workspace after commit
`5c2f93e`. It records work and acceptance requirements, not passing results.
Each stage uses a separate pull request, with command-family pull requests for
larger stages. Finish a stage before beginning the next. The current delivery
stops after stage 0: publish only `cli/core@0.7.0`, `cli/curl@0.2.3`,
`cli/mv@0.2.3`, and `cli/wget@0.2.3`, then verify exact MoonX coordinates.
The other 75 published commands retain their registry versions and remain
unpublished source candidates. Later stages require a subsequent continuation.

Stage 0 publication and exact-version MoonX acceptance are complete; see the
[release record](reports/2026-10-20-stage0-release/README.md). This delivery stops here. Later
stage entries below retain their original requirements and are not completion
claims.

## Ordered stages

| Stage | Required implementation | Acceptance and retained boundaries |
| --- | --- | --- |
| 0: async 0.22.5 | Upgrade core, all 79 current commands and tests; distinguish response-header/receive/body failures; repair curl/wget partial output and Wget retry/resume effects; add explicit Windows symlink/junction rename fixtures. | Native/Wasm command status, bytes, files, retries and wire requests; fixed curl/Wget oracle; independent Windows Native/Wasm link and referent observations. Wasm host fixes are not inferred from the package version. |
| [#27](https://github.com/moonbit-community/cmd/issues/27): gzip | Reusable raw DEFLATE, 32 KiB LZ77, fixed/dynamic Huffman, block cost selection, real levels 1-9/default 6, and Reader-based incremental decoding. | GNU interoperability in both directions, compression ratio, member/CRC/ISIZE/truncation/partial-output contracts, throughput and bounded-memory observations. Metadata-preserving named replacement remains a separate issue. |
| [#28](https://github.com/moonbit-community/cmd/issues/28): sed | Instruction execution with hold space, branches/groups, multiline commands and append/insert/change; shared BRE/ERE matcher with captures, backreferences and C-byte word assertions. | GNU matching/capture and script-cycle comparisons, invalid-script effects, partial output, long-line complexity and expr regressions. In-place editing and additional GNU/locale extensions remain separate issues. |
| [#30](https://github.com/moonbit-community/cmd/issues/30): diff/patch | Whitespace/case/CR and ordinary-directory diff; linear-space edit reconstruction; per-hunk offset/fuzz/results, reject files and mixed success. | Exact hunk and file-effect comparisons plus bidirectional GNU roundtrips; dry-run has no output files. Metadata-preserving replacement and unsupported link semantics remain separate issues. |
| [#33](https://github.com/moonbit-community/cmd/issues/33): common options | Complete the algorithmic/path option families listed below, without reimplementing existing options. | Freeze exact options/conflicts per family, compare bytes/status/side effects, and register rejection evidence for API-dependent combinations. |
| [#32](https://github.com/moonbit-community/cmd/issues/32): resources | Incremental text processing, efficient line scanning, reverse reads/spooling, two-pass column layout, external sort, bounded diff/gzip resources. | 8/64/512 MiB record corpora and separate long-record cases; output equivalence, interruption/cleanup, elapsed time, peak memory and temporary disk. Fixture sizes are not product limits. |
| [#35](https://github.com/moonbit-community/cmd/issues/35): new modules | Practical C-byte POSIX-style awk; ordinary-file/directory USTAR and ZIP32 stored/DEFLATE read/write subsets in tar, zip and unzip. | Pin new oracles before claiming parity; publish each first coordinate separately. Preserve every remaining planned command and unsupported format/capability in linked child issues. |

## Complete common-option inventory

- Text selection/combination: cut complement/output delimiter; uniq grouping;
  comm delimiter/total; join ignore-case/header/automatic output; wc total.
- Sorting/formatting: sort stable/merge/output/random-source; seq formats;
  fmt crown/tag/prefix; documented printf extensions; relative/repeating tab stops.
- Splitting/reversal: split chunk/line-byte/filter/start/hex suffix modes;
  csplit suffix/suppress; rev/tac multiple files and tac regular expressions.
- Byte display: od float/string/traditional offset; hexdump format/color/stdin
  skip; cmp byte display; strings separator; xxd formats/seek/output files.
- Checksums: cksum algorithms/check/tag and consistent tagged/hash manifests.
- Paths/directories: lexical/relative realpath; mktemp parent/suffix/template/
  quiet; symbolic mkdir modes; interactive rm; ls layout/quoting; tree
  JSON/HTML/filter/reporting; explicit colors without terminal autodetection.
- Execution/output: env split-string; xargs delimiters and supportable prompts;
  tail record options; tee output-error policies.

Filesystem identity/readlink/metadata setters, terminal autodetection, process
observation and non-C locale requirements remain individually tracked. Random
sorting must define and test its random-source contract, rather than treating an
arbitrary implementation's sequence as GNU differential evidence.

## Resource and new-module contracts

Use 64 KiB I/O blocks. External sort defaults to a 64 MiB accounted sorting-data
budget and at most 16 merge inputs; oversized records and runtime/object overhead
are measured separately. rev/strings/split process incrementally, csplit retains
only required lookback or spools, tac reverse-reads regular files and spools
stdin, and column uses a second pass. Owned temporary files must be cleaned on
errors and cancellation. Neither diff nor the process RSS is claimed constant.

Awk includes command-line/repeated-file programs, field/record variables,
BEGIN/END and range patterns, expressions/control flow, associative arrays,
functions, common string/math builtins, print/printf, ordinary getline and file
redirection/close. RS initially supports a single byte and paragraph mode.
System commands/pipes, GNU extensions, non-C locale and RNG extensions are
explicit follow-ups, not automatically upstream API blockers.

Archive creation requires the project extension `--metadata=normalized`:
USTAR uses UID/GID 0, empty owner/group names, modes 0644/0755 and mtime 0;
ZIP uses the fixed 1980-01-01 DOS date and ordinary file/directory attributes.
Filesystem extraction requires `--metadata=none`: create new ordinary entries
without restoring owner/time/ACL/xattr metadata. Listing and stdout extraction
need neither option. Reject existing-output overwrite/update/append, archive
links, special files, path escapes, encryption and unsupported formats. Source
paths are archived by content without claiming hard-link identity detection.
PAX, ZIP64, links and metadata preservation remain tracked follow-ups.

## Evidence, issues and release

Keep code, help, README, catalog, compatibility, canonical ADR and regression
bindings coherent. Use pure MoonBit for product code, fixtures and automation.
Do not substitute host commands or private runtime APIs for missing capabilities.

Required evidence includes actual command/package behavior, Native/Wasm and
backend pairs, policy boundaries, applicable Windows observations and a sealed
immutable upstream oracle. Unavailable observations are infrastructure failures,
not passes. Run the exact-commit coverage gate before every applicable push and
retain the required three-platform PR/mainline checks.

The dependency upgrade changes all 78 currently published command declarations.
Choose unused candidate versions from live registry evidence; keep timeout local
only. Existing published manifests and historical expectations remain frozen.
Stage 0 checks the 81-manifest dependency invariant and can validate each module
in a minimal workspace with the unpublished local core. This is not standalone
registry resolution. The stage-0 release scope is core, curl, mv and wget;
exact standalone registry consumers and exact-version MoonX checks are part
of that release acceptance. Preserve the unselected commands' existing frozen
published coordinates and expectations when recording this partial release.
Publish core first, then curl, mv and wget serially in lexical order, verify
each upload/registry coordinate, and run exact-version MoonX smoke/differentials.

After publication acceptance, close completed stages in sequence. For partial
issues, first create child issues containing each unmet acceptance condition,
its project/API/platform classification and its unlock criteria. Closure records
must link those children and the delivered evidence without claiming complete
GNU compatibility. Issues #10 and #20 are not closed by a dependency bump; the
other work in #31 and #34 is outside this sequence.

## Current progress

Stage 0 is undergoing final CI and partial-release preparation. Later stages
have not started. No new registry publication or issue closure is claimed by
this document.
