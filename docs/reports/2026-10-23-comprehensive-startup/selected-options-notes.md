# Selected #33 option inventory before implementation

Date: 2026-10-23 (Asia/Shanghai). Source revision:
`a60e4279666ef9bf99ab05e34a4cd85804cfde5f`, inspected in
`/Users/winter/.codex/worktrees/cmd-comprehensive-c0/cmd`.

This is prerequisite source review while C0 is pending. It starts no O-phase
implementation, changes no product file, and supplies no GNU, platform,
backend-pair, publication or performance acceptance. No Moon or oracle command
was executed. `o-options-inventory.json` is the machine-readable companion;
it records precise code lines and, for all 35 selected commands, the reviewed
help, README, catalog and support record. Line references below resolve at the
source revision above, not at a future moving branch.

There are **47 option/behavior groups across 35 commands**: four existing-path
groups to preserve, two visible implementation/declaration defects, 37 missing
project-work groups, and four conditional existing filesystem/API boundaries.
These are inventory groups, not acceptance-bullet counts. The conditional
boundaries do not excuse new-file, lexical or ordinary-file algorithm work.
“Existing” means a code path was inspected; its full oracle conflict matrix has
not been revalidated.

| Stage / command | Selected gap and present behavior | Source anchor |
| --- | --- | --- |
| O1 cut | Add complement/output delimiter. Keep existing range modes, field delimiter validation and NUL scanner. | `commands/cut/main.mbt:155`; field output at `:67` |
| O1 uniq | Add all-repeated/group modes and separators. Current state emits one representative per adjacent run; keep count/unique/repeated/skip/key logic. | `commands/uniq/main.mbt:72`, `:152` |
| O1 comm | Output delimiter/totals absent; prefixes hardcode TAB. Keep dual-stream merge, suppression and order handling. | `commands/comm/main.mbt:79`, `:101`, `:162` |
| O1 join | Ignore-case/header absent; `-o LIST` exists, `-o auto` does not. Keep equal-key run streaming and explicit output fields. | `commands/join/main.mbt:122`, `:419`, `:514` |
| O1 wc | Total policy absent; current total row depends on operand count. Existing count modes/files0-from/alignment are present. | `commands/wc/main.mbt:259`, `:318` |
| O2 sort | Stable/merge/output/random-source absent. `-R/--random-sort` is recognized then rejected, not implemented random sorting; `--sort=random` alias also needs work. Preserve existing key/modifier comparisons and order checks. | `commands/sort/main.mbt:810`, `:842`; normalization `:799` |
| O3 seq | Format option absent. Preserve exact decimal/exponent arithmetic, streamed output, -s/-w and explicit numeric bounds. | `commands/seq/main.mbt:174` |
| O3 fmt | Crown/tagged/prefix absent and explicitly excluded by help. Keep current width/goal/split/uniform/indentation behavior. | `commands/fmt/main.mbt:19`, `:28` |
| O3 printf | `%a/%A/%q` reach invalid conversion. Existing f/F/e/E/g/G, flags, width/precision/star, repetition, escapes and diagnostic-prefix handling already exist. | `commands/printf/main.mbt:818`, `:879` |
| O4 expand | /N and +N tail grammar absent; fixed ascending stops and one repeated interval exist. | `commands/expand/main.mbt:7`, `:31` |
| O4 unexpand | Same missing tail grammar; retain existing all/first-only/fixed stops and pending spaces. | `commands/unexpand/main.mbt:7`, `:31` |
| O5 split | Six chunk forms, line-bytes, filter, hex suffix, optional numeric FROM and applicable elide modes absent. **Basic -d/--numeric-suffixes starting at zero already exists**. Preserve suffix width/growth/exhaustion/additional suffix and exclusive creation. | `commands/split/main.mbt:129`, `:181`, `:189` |
| O6 csplit | Custom suffix formatter/suppress-matched absent. Keep numeric/regex boundaries, offsets/repeats, -z/-k and owned-file cleanup. | `commands/csplit/main.mbt:15`, `:129` |
| O6 rev | Multiple inputs explicitly rejected; single-file/stdin byte reversal and exact line-feed preservation exist. Help's FILE... overstates current input scope. | `commands/rev/main.mbt:32`, `:59` |
| O6 tac | Regex recognized then rejected; multiple files rejected. Fixed separator/before behavior exists; help's FILE... likewise overstates scope. | `commands/tac/main.mbt:66`, `:88`, `:105` |
| O7 od | Floating types/aliases, strings and traditional offset/label absent. Keep integer/character/endian/count/width/folding paths. Freeze actual ABI alias inventory before implementation. | `commands/od/format.mbt:50`; `commands/od/main.mbt:112` |
| O7 hexdump | Custom format/color language absent. **Forward stdin skip is incorrectly attributed to a missing seek API** although its own Reader discard state exists. Preserve built-in format/offset/folding logic. | `commands/hexdump/main.mbt:29`, `:105`; `commands/hexdump/stream.mbt:40`, `:63` |
| O7 cmp | Print-bytes absent; keep first/verbose/silent comparison, limits/skips and error precedence. | `commands/cmp/main.mbt:160` |
| O7 strings | Output separator absent. Keep current s/S encodings, TAB, offsets and filename/multifile behavior. | `commands/strings/main.mbt:114` |
| O8 xxd | Requested a/b/e/E/g/u/o selectors, relative/end-relative state and second output operand absent. **Nonnegative forward discard and positive plain-reverse -s prefix already exist. Addressed reverse silently ignores parsed -s.** | `commands/xxd/main.mbt:351`, `:409`, `:430`, `:464`, `:478` |
| O9 cksum | Algorithm/length/check/tag/base64/raw modes absent; current command only computes POSIX CRC plus length. Existing public/shared MD5/SHA1/SHA512 and standalone SHA256 are reuse candidates. | `commands/cksum/main.mbt:85`; `core/checksum/digest.mbt:2`; ADR-0008 `:95` |
| O9 md5sum | Tag/tagged checks absent; untagged manifest parser/escaping/flags/summaries already exist through core. | `core/checksum/run.mbt:101`, `:115`; `core/checksum/records.mbt:56` |
| O9 sha1sum | Same shared implementation and gap; do not create another record parser. | Same shared source; `commands/sha1sum/main.mbt:3` |
| O9 sha256sum | Tag/tagged checks absent; separate untagged checker already exists. Backslash/LF escaping exists, but its CR handling differs from shared core and needs oracle comparison before a repair claim. | `commands/sha256sum/main.mbt:44`, `:96`, `:189` |
| O9 sha512sum | Same shared tag gap; incremental digest/untagged checks already exist. | `commands/sha512sum/main.mbt:3`; shared source above |
| O10 realpath | Selected lexical -s/-m, relative output and quiet parser absent. Current code delegates to public realpath and has -e/-z/ordered operands. Physical missing-path link resolution is a separate readlink boundary. | `commands/realpath/main.mbt:7`, `:31`; ADR-0004 `:169` |
| O10 mktemp | tmpdir/-t/suffix/quiet and full GNU defaults absent. Existing default uses TMPDIR or /tmp plus tmp.XXXXXX; preserve secure randomness, atomic create, collision retries and 0600/0700. -u stays excluded. | `commands/mktemp/main.mbt:20`, `:42`, `:52`, `:106` |
| O10 mkdir | Symbolic mode parser absent. Numeric leaf-mode creation/chmod already exist; symbolic evaluation is project work, with omitted-who umask and platform effects to verify separately. | `commands/mkdir/main.mbt:2`, `:75` |
| O10 rm | Interactive modes absent. Preserve current safe deletion/force/root/operand ordering. Verify rm's own prompt input semantics; do not automatically impose xargs's separate-channel rule. | `commands/rm/main.mbt:18` |
| O11 ls | Selected layouts/width/tab/quoting/explicit color absent; current renderer prints raw name plus classify suffix per line. Existing entry/type/executable/sort/link behavior is reusable. Explicit color does not require auto TTY detection. | `commands/ls/main.mbt:225`, `:281` |
| O12 tree | Selected JSON/HTML/filter/prune/size/color options absent. Current ordinary-tree traversal/count/depth/hidden/full-path/noreport remains useful. Symlink/metadata limits must not block ordinary-file output algorithms. | `commands/tree/main.mbt:99`; ADR-0004 `:170` |
| O13 env | Split-string absent. Preserve complete environment, assignment boundary, unset/chdir/null and direct-child status behavior; never delegate splitting to host shell. | `commands/env/main.mbt:33` |
| O13 xargs | Delimiter and prompt modes absent. Existing whitespace/NUL/batch/replace/eof/parallel behavior is substantial. Independent confirmation API still needs exact discovery; no new API-absence proof was performed. | `commands/xargs/main.mbt:285`, `:392` |
| O13 tail | NUL-record mode absent. Preserve current signed line/byte origins, headers and descriptor-follow behavior; -F's identity boundary is independent. | `commands/tail/main.mbt:445` |
| O13 tee | Output-error modes/-p absent. Stdout writes currently sit outside per-file write catches. Preserve append/shared64KiB/per-file continuation; discover actual pipe/file error classification before declaring an API block. | `commands/tee/main.mbt:10`, `:48` |

## Boundaries and declaration debt

The four conditional boundary rows cover future sort/xxd existing-target and
hard-link identity/handle truncation, physical missing-component realpath link
resolution, and tree link-target/identity/metadata. They reference existing
ADR-0004/support records. Fresh public-API capability checks and rejection
evidence are still required at implementation; this inventory does not freeze
an old API claim as current proof. Safe new files, lexical paths, explicit ANSI,
ordinary-file sizes, byte formatting, regexes and numeric algorithms remain
project work.

Three declaration issues merit preservation in later changes: rev/tac help
advertises multiple files that source rejects; hexdump mislabels forward stdin
discard as requiring seeking; and xargs catalog omits source-supported
max-lines/max-chars/max-procs/eof/show-limits. Sort's catalog random-sort entry
must continue to be read together with its explicit rejection. SHA256 versus
shared-core CR escaping is an **unverified discrepancy**, not a newly proven GNU
defect.

## Unverified oracle contracts

Every group still needs the frozen option/alias/cluster/=value, repeat/order/
conflict, invalid-value and -- operand matrix, plus byte/status/effect and
partial-error observations. Especially unresolved are sort random-source
consumption/hash/order; printf/seq/od ABI precision; join/header/auto and group
separators; chunk/filter lifecycle; reverse-address adjustment; digest tagging
and CR/CRLF; umask/prompts; quoting display widths; tree prune/report order;
and tee pipe classification. Exact questions are keyed by O1-O13 in JSON.

No compatibility status should be promoted from these source classifications.
Implement only after prerequisite stage gates, and update help/README/catalog/
support/ADR/registry/tests together when behavior actually changes.
