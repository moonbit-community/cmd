# Command Support Record

Date: 2026-09-05
Updated: 2026-10-25

Stage 0 publishes `cli/core@0.7.0`, `cli/curl@0.2.3`, `cli/mv@0.2.3`
and `cli/wget@0.2.3` with async 0.22.5. The other 75 published commands
retain their registry coordinates and frozen expectations; their workspace
dependency upgrades remain unpublished candidates. `timeout` stays local-only.
The [stage 0 release report](reports/2026-10-20-stage0-release/README.md)
records the four verified uploads, exact main-source three-platform gates,
local MoonX contracts, published platform acceptance and immutable oracle.

There are **79 local command modules and 78 published commands**.
Published command versions are **39 at 0.2.1, 5 at 0.2.2, 3 at 0.2.3,
15 at 0.1.1, 15 at 0.1.2 and 1 at 0.1.3**. Shared `cli/core` is **0.7.0**
and is not counted as a command.

The [metadata release](reports/2026-10-15-metadata-release/README.md)
and [fidelity repair](reports/2026-10-11-fidelity-repair/README.md) remain
historical evidence for their original coordinates. The retained commands
keep their earlier dependency and acceptance profiles.

Authorization belongs to the caller/host. Catalog capabilities and the older
restricted label describe requirements, not command-local policy.

## Workspace O5-O13 option candidates

These unpublished implementation candidates extend the selected O stage; the
registered cases and package tests describe current source behavior. Private
Native/Wasm comparisons are development evidence. Required PR checks,
actual-main acceptance, formal direct-Wasm resources/performance and publication
remain separate gates. Tree uses directory sizes only when its released public
backend actually returns them; no portable inode-size constant is assumed.

| Family | Current source behavior | Retained boundary |
| --- | --- | --- |
| split | All selected byte/line/round-robin `-n` forms, `-C`, suffix starts/growth, elision and pure MoonBit `--filter` sessions with `$FILE`, stdin and observed child status. | Ordinary existing outputs still reject. GNU's undefined hexadecimal FROM=a-f indexing is excluded; the workspace uses documented base-16 arithmetic. |
| csplit, rev, tac | Csplit integer suffix descriptors and suppress-matched offsets; ordered rev/tac operands and tac's GNU Emacs C-byte regex selection. | Existing csplit outputs reject. Whole-input/index resource work is separate from option correctness. |
| od, hexdump, cmp, strings | Frozen Linux numeric formats, strings/traditional od offsets, custom hexdump formats/color rules, cmp byte notation and strings separators. | Wide strings encodings remain rejected. Hexdump forward stdin discard is an explicit extension: util-linux 2.40 rejects seek on a pipe, while equivalent named-file display supplies the byte reference. |
| xxd | Autoskip/style/group/case/EBCDIC, wide named-input seeks, forward stdin discard, reverse address adjustment and new named outputs with backpatching. | Existing output alias/mode/content preservation needs public file identity and descriptor operations; backward/end-relative stdin positioning needs a seekable public input. |
| checksum commands | Cksum algorithm/length selection, modern tagged/base64/raw records and checking; consistent tags, escaping and manifest flags for the four sum commands. | The selected C byte profile does not claim Windows text translation. Public digest implementations and bounded incremental state remain shared. |
| realpath, mktemp, mkdir, rm | Component-wise missing/strip/relative realpaths, GNU temporary templates/tmpdir/suffix/exclusive creation, umask-independent symbolic directory modes, and explicit once/per-entry removal prompts. | Unresolved physical link targets need readlink. Umask-dependent modes, unknown parent raw mode and unsupported Windows setters reject. Automatic terminal-dependent rm prompting is separate from implemented explicit prompts. |
| ls | C quoting/layout/tab width and explicit color with type/suffix/link-target selection, preserving raw color bytes. | Color auto detection rejects; enabled mode/capability/link-count predicates reject only relevant entries. Effective access is not GNU's raw execute-bit predicate. |
| tree | Iterative filtered/pruned JSON/HTML/text traversal, safe escaping, C branches, explicit type/suffix color, selected sizes and postorder disk-usage totals. | Public directory size works on Linux and fails on the observed macOS backend; Windows uses the real API result. Readlink and raw-mode color predicates retain narrow boundaries. HTML page metadata/safety differences are deliberate contracts. |
| env, xargs, tail, tee | Env split-string grammar/expansion/splicing; byte delimiters and separate xargs confirmation input; tail NUL records; tee's five explicit pipe-error policies with actual closed-pipe scenarios. | Invalid-byte argv needs public byte transport. Unavailable confirmation channels reject before argument input. Default tee SIGPIPE termination needs a released restore/raise API; it reports status 2 rather than a fabricated signal result. |

The four former od-float, hexdump-format/stdin-skip and md5sum-tag boundary IDs
now bind positive regressions. New explicit boundaries retain their rejection
cases and unlock conditions in the canonical ADRs. Generated mktemp scenarios
observe name/type/content/mode relations; closed-stdout tee scenarios observe
status, stderr and later file effects without claiming captured stdout.

## Workspace O2-O4 option candidates

Unpublished sort **0.2.2**, seq **0.2.3**, printf **0.2.2**, fmt **0.1.2** and
expand/unexpand **0.1.3** add the selected sorting, numeric-format, paragraph
and tab-grid families. Shared numeric, C-byte shell quoting and tab-stop code
selects core **0.8.0**. Current source and private Native/Wasm GNU development
observations are separate from PR/main, formal performance and publication
acceptance; all existing published coordinates above remain unchanged.

Sort adds stable ties, bounded fan-in merge, ordinary output aliases and exact
16-byte seeded GNU random ordering. Merge assumes ordered inputs. Existing
streaming merge outputs retain an explicit identity/error-effects rejection;
normal output and new merge targets are supported. See ADR-0003 and ADR-0004.
Fatal sort errors exit 2, including host temporary-write denial; denied spills
retain empty stdout and the host diagnostic.
Fmt adds crown/tagged/prefix behavior without replacing its paragraph optimizer.
The shared tab cursor supports repeated lists and absolute/relative trailing
grids with GNU precedence and control-byte behavior.

Seq `-f` and printf use the frozen Linux amd64 Extended80 numeric profile on
every backend, including exact hexadecimal/decimal rounding and selected
endpoint recovery. Printf also supports GNU C-byte `%q`. This fixed profile is
distinct from the macOS GNU build's binary64 long double; native ABI/locale
equivalence is not inferred. The original default seq precision limits remain.
The small local Rosetta argv0 diagnostic difference is recorded in ADR-0008.

## Workspace O1 text-option candidates

Unpublished cut, uniq, comm, join and wc **0.2.2** add the selected complement,
delimiter, duplicate-group, merge-header/field and total policies. Their current
PR #52 and actual-main run 40110917627 passed all required platform and
coverage checks. Publication remains separate. The exact contracts are in the current case
corpus and [streams ADR](adr/0003-streams.md).

Wc -m now follows the selected C byte profile, including invalid UTF-8, and
no longer maintains a UTF-8 decoder. Named-file widths follow size metadata;
multi-counter stdin uses stream-width padding. Exact GNU physical-fstat width
for regular-file redirection to stdin remains a public descriptor-metadata
limit, independently of total-only output and counter correctness.

## Workspace diff and patch candidates

Unpublished diff and patch **0.2.0** select core **0.8.0**. Diff adds C-byte
case/whitespace/blank/CR comparisons and ordinary directory workflows with
recursive, new-file and unidirectional-new-file modes. Comparison keys are
separate from displayed records; `--strip-trailing-cr` also strips the CR from
displayed LF-terminated lines. Edit reconstruction uses linear auxiliary
frontiers and an explicit work stack. Inputs, keys and output remain separately
allocated; this is not constant-memory or linear-time diff.
Directory FIFO/socket entries receive type reports. Distinct character/block
device comparisons require public device-number metadata and retain a POSIX
rejection scenario; top-level readable special files remain input streams.

Patch adds offset/fuzz selection (default fuzz 2), cumulative displacement,
used-region protection, batch reverse detection, later-hunk continuation and
unified/context reject output. New reject files are created exclusively; a
single invocation can append multiple file results to its own reject handle.
Dry-run creates neither target nor reject files. Existing target/named-output
mode preservation and existing-reject replacement remain explicit filesystem
boundaries in [ADR-0004](adr/0004-filesystem.md). GNU interaction and extended
binary/rename/mode patch formats are outside this selected profile.

Performance acceptance now measures direct release Wasm, as selected by the
user on 2026-10-24. MoonX launcher cost is outside that gate. Existing published
coordinates and their semantic acceptance remain unchanged.

## Workspace stream optimization candidates

Unpublished core 0.8.0 uses a reusable 64 KiB line scanner. Comm, cut, head,
join, jq, nl, paste, sed, sort, uniq and xxd now resolve that candidate so their
published consumers can receive the scanner when a release is accepted.
Cat reuses a 64 KiB copy buffer, wc computes selected counters, and strings
streams accepted printable runs. Accepted options and byte profiles remain.
Head batches output in 64 KiB blocks. Cp and mv select core 0.8.0 for new-file
copying; mv advances to an unpublished 0.2.4 candidate because its dependency
resolution changes. Existing filesystem capability boundaries remain.
Sort caches comparison transformations and uses stable disk runs under a
64 MiB accounted run budget with at most sixteen merge inputs. This budget
does not include all allocator/GC or oversized-record costs and is not an RSS cap.
The [development observations](reports/2026-10-24-stream-hotpaths.md) record
local correctness and timing separately from final resources, MoonX and release
acceptance. Current published coordinates above remain frozen.

## Workspace matcher and sed candidates

Core **0.8.0**, grep **0.3.0**, and sed/expr/csplit **0.2.0** are unpublished
workspace candidates. The published coordinates and frozen expectations above
remain unchanged. [PR #49](https://github.com/moonbit-community/cmd/pull/49)
merged the S implementation after all required platform and coverage checks.
The [S implementation report](reports/2026-10-24-s-matcher-sed.md) records its
development evidence. Performance and publication remain separate roadmap gates.

The shared C-byte matcher parses BRE/ERE once, supports the tested byte classes,
word assertions and pattern backreferences, and exposes span-only search
to grep. Csplit and sed regex addresses use a capture-free predicate; expr and
sed substitutions request capture registers, following GNU's distinct calls.
Grep's ASCII `-i` expands literals/classes before class negation,
preserves assertion escapes and compares references without changing captured
bytes. The O6 tac candidate adds its distinct GNU Emacs syntax; nl retains its
earlier matcher profile.
Distinct capture/reference states can require exponential resources; no hidden
matching-step cap is imposed. Non-C locale and complete GNU grammar remain open.

Sed now uses compiled instructions for hold space, labels/branches, groups,
`n/N/P/D/a/i/c`, and the existing address/substitution commands. A multi-file
streaming cursor and lazy last-line checks preserve the exercised EOF, queued
output and missing-input behavior. Pattern/hold growth and branch termination
remain script-controlled. Diagnostics use project formatting; `-i` still needs
the replacement/metadata contract in [ADR-0004](adr/0004-filesystem.md).

Repeated nullable captures now use GNU candidate selection and capture-register
restoration, including counted repeats, nested captures and multiple references.
Independent local GNU comparisons match all 1,095 applicable cases; three oracle
faults are retained separately. The earlier compile-time rejection is removed
and the consumer cases exercise supported matching. These development results
do not establish complete GNU/POSIX compatibility. PR #49 supplies platform,
oracle and coverage evidence for its scope; publication and performance remain.

## Accepted stage 0 subset: async 0.22.5

[Roadmap stage 0](command-roadmap.md) is accepted for the four coordinates
above. The following implementation decisions and acceptance contracts are
covered by the linked release evidence. Broader API, host and command-feature
limits remain explicit; this does not establish full upstream compatibility.

| Accepted area | Implemented decision | Acceptance contract / retained boundary |
| --- | --- | --- |
| Windows link rename | Native consumes async's reparse-point rename fix. Windows Wasm rejects source symlink/junction moves and destination-link backups before prompting or mutation; no-clobber and update-none skips remain. No `-u` link-skip acceptance is claimed. Regular-source replacement of destination links without backup is covered by actual Windows source and published-host evidence. | Actual Windows Native/Wasm results for forced file/directory/dangling symlinks, junctions, backups and referents; interactive refusal with stdin open and no prompt; package fault-injected Native link-backup restoration. Identify a fixed released host before lifting the Wasm rejection; a dependency version is not host evidence. See ADR-0004 and [#38](https://github.com/moonbit-community/cmd/issues/38). |
| curl response failures | `CurlProfile` maps empty replies to 52, partial bodies to 18 and other receive failures to 56. Ordinary file output opens on first payload or successful completion and buffers 4096 bytes. An earlier network failure remains primary if the final tail flush also fails; an earlier write failure returns 23. An initial empty failure preserves ordinary unopened destinations, including with `--remove-on-error`. A redirect requiring consumed stdin to rewind returns 65. | Native/Wasm status, bytes, existing/absent files, cleanup and retry effects against the sealed curl oracle. File buffering does not establish stdout error precedence. `--retry-all-errors` may send empty stdin on a later attempt after consuming it, matching the fixed oracle; redirect rewind and empty-upload controls require separate wire evidence. |
| curl retry and selected filenames | An accepted retry resets an opened regular output file before the next request. Cleanup of an opened selected file occurs only after final failure; successful retries keep their result. With `-O -J`, a valid Content-Disposition filename on a 2xx/3xx response creates exclusively before body delivery; an existing selected filename returns 23 unchanged. Other statuses keep ordinary URL-derived output selection, and enabled `-f` rejects HTTP errors before opening output. Retries keep the first server-selected name even if later headers change or omit it. Strict and Wget profiles retain their existing behavior. | Observe file bytes before the retry response and after final failure/success, including initial empty-failure and existing-name controls. Status controls cover 200/304 and 404/500 with and without `-f`. Exploratory fixed curl probes define expectations; actual registered Native/Wasm and sealed-oracle passes are retained in the release evidence. Path-based reset uses released APIs but does not establish descriptor/inode identity during concurrent path replacement; retain [#10](https://github.com/moonbit-community/cmd/issues/10), with the unlock condition in ADR-0005. |
| URL request targets | Initial raw ASCII space/TAB/CR/LF/DEL in path/query returns curl 3 before connecting and preserves existing output; Wget uses uppercase percent escapes. Existing encoded bytes remain encoded. Redirect spaces use curl path `%20`/query `+`, or Wget `%20` in both; TAB uses `%09` in both commands. | Fixed probes establish these specific expectations. Require fresh Native/Wasm raw-wire, connection-count and output observations, encoded controls, and sealed-oracle comparison. This is project validation/encoding through released APIs, not a new API requirement. |
| Response cookie fields | Final Set-Cookie names, values, attribute order and repeated-field order remain observable separately from parsed storage, after HTTP optional-whitespace normalization; interim fields are excluded. Both commands ignore fields without `=` without failing complete bodies. Nonnumeric Max-Age deletes the matching curl cookie; Wget ignores the replacement. Positive decimal overflow keeps curl's replacement under its 400-day cap, but Wget expires the matching cookie for numeric overflow below 32 digits. Curl orders by descending path/domain/name byte length, then newer creation; Wget uses descending domain/path byte length, then name/value byte order. | Verify repeated-field order, old/new cookie state, subsequent request bytes, complete bodies and header observations independently on Native/Wasm and the sealed oracle; fixed-clock tests cover expiry limits. This does not relax outgoing Cookie-field CR/LF rejection or establish cookie-jar byte parity or every malformed-cookie rule. |
| Header EOF profiles | Public `TransferProfile` defaults to `StrictProfile`. The command profiles accept EOF while collecting headers after a complete 200 status line, preserving all already parsed framing checks. The unfinished `Content-Len` fixture succeeds with zero bytes; strict transfer rejects it. | Actual Native/Wasm and fixed-oracle cases for empty replies, incomplete status/header bytes, known Content-Length with unfinished later fields, and malformed headers. Accepting header EOF does not bypass known body-length requirements. |
| Wget retry/resume | `WgetProfile` retries failed network reads from delivered bytes and reuses the selected output path. Mismatched resumed Content-Range returns 4 after retries. A complete shorter known-length 200 preserves the prefix and succeeds; 416 succeeds without opening transfer output. Explicit `-O` still initializes its aggregate file before requests. Continued GET with Content-Disposition first discovers the name using HEAD, then uses that file's offset. | Fixed Wget comparisons for stdout, partial files, shared `-O`, selected filenames, retries and wire requests. Wget does not retry consumed stdin bodies; unchanged remote prefixes are not verified. Verify HEAD/GET order and existing/absent destination effects separately. Core still rejects a direct resumed switch to a different output path; see ADR-0005. |
| Chunk framing edges | The project parser delivers chunk payload before later framing checks. `WgetProfile` accepts EOF in remaining chunk payload, including zero bytes, or trailers; EOF in chunk-size lines or completed-chunk separators still fails. Strict and curl profiles retain chunk truncation failures. | Fresh Native/Wasm and oracle comparison for each EOF state, malformed chunks, retained prefixes and complete chunk/trailer, close-delimited and bodyless controls. This is project implementation through existing public byte APIs, not an upstream API blocker. See ADR-0005. |
| Encoded transfer bytes | Request identity encoding by default, preserve explicit Accept-Encoding, and retain content-coding bytes unchanged. Validate resumed 206 body byte spans even without Content-Length; bodyless responses do not consume a resume prefix. | Native/Wasm gzip-coded fixed-length success/truncation and resumed chunked/close-delimited span regressions; fixed-oracle command comparison remains required. Automatic decompression is not added. See ADR-0005. |
| HTTP/1 metadata and remaining scope | Reject protocol lines above 64 KiB, cumulative headers above 1 MiB, more than 1024 fields per block, more than 128 interim responses or more than 1024 trailer fields; header failures preserve output and trailer failures retain delivered bytes. Proxy CONNECT still uses async's high-level client path. | Registered rejection regressions require actual backend runs. Ordinary repeated request-header semantics remain project work under [#34](https://github.com/moonbit-community/cmd/issues/34); no new upstream list API is required. |

Generated request fields, including Cookie data, now receive the existing
invalid-header checks before any request bytes are written. A private sink
scope guarantees file closure on task cancellation; it does not establish
buffered-tail or cleanup parity for cancellation, which remains in stage 5.

Curl's `-sS` preserves an intermediate transfer-error diagnostic even if the
retry succeeds; fixed-length truncation reports its structured missing-byte
count. The registered binary-stdin retry scenario compares those stderr bytes
as well as both request bodies. Internal HTTP-status retries without `-f` do
not produce a false error 22 diagnostic.

These selected rows are promoted by actual Native/Wasm runs, backend-pair
observations, exact-revision coverage audits and exact-version published
acceptance in the stage 0 release report. Missing Windows symlink privileges
or link observers are
infrastructure failures. The public filesystem/terminal/process API blockers
remain unchanged by async 0.22.5.

## Workspace metadata contract

The current workspace gives every command the same standalone
metadata contract. With exactly one metadata argument, `--help` writes usage
text to stdout, ends with a newline, and exits 0; `--version` writes
`<command> <package-version>` followed by one newline and exits
0. Help text uses the phrases `display this help and exit` and `display version
and exit`. Metadata is handled before command input is opened, so these calls do
not consume stdin or create command fixtures. The Native probe
`tests/metadata/verify.mbtx` passed **79/79** commands on 2026-10-12, including
the local-only `timeout` package. The corresponding Wasm probe also passed
79/79 commands. The command catalog declares `help` and `version` for every
contract.

The dated 2026-10-12 probes are workspace evidence. The exact published MoonX
audit in `docs/reports/2026-10-12-readme-audit/` records older immutable
coordinates, including the old metadata behavior, separately.

The historical metadata release verified its original coordinates with
core 0.6.0. Its 72 core-dependent published commands requested that version.
The three stage 0 commands now request core 0.7.0; the other 69 retain core
0.6.0. Six independent commands remain independent and `timeout` stays local-only. New exact help
and version cases cover all 78 published commands. The local exact
`cli/sh@0.2.1` probe passes both metadata operations, fixing the reported
`sh@0.2.0` limitation. Full published acceptance and the current frozen pointer
are recorded in the [release report](reports/2026-10-15-metadata-release/README.md).
These closed-stdin captures prove status and output bytes; they do not measure
whether an open input stream remains unread.

This is the single support record for the `cmd` repository. It replaces the
former matrix. Historical implementation stages are archived in
[`reports/README.md`](reports/README.md); claims are promoted through the
unified runner: native black-box semantic tests,
pinned-upstream differential cases, and separate Wasm authorization tests for
restricted commands. The relevant
artifacts are built once and passed to the runner; a test case does not rebuild
the command.

```text
cmd-test-runner --suite compat --native-root <prebuilt-native-root>
cmd-test-runner --suite oracle --native-root <prebuilt-native-root>
cmd-test-runner --suite policy --wasm-root <prebuilt-wasm-root>
```

The audit uses isolated temporary fixtures and explicit Wasm policies for file,
process, and network access. `subset verified` means that the listed profile has
repeatable semantic evidence; it is not a claim that every upstream option is
implemented. `help-visible only` means an artifact prints the option in
`--help`, but the unified runner does not yet have complete positive and
negative evidence for it.

The historical implementation roadmap and its stage evidence are archived in
[`reports/README.md`](reports/README.md). They are historical context, not an
additional support claim.

## Published-version verification

`tests/release_runner` is the published-consumer gate. It is a native MoonBit
runner that starts exact `moonx cli/<command>@<version>` invocations through
MoonBit's process API and compares them with the pinned Linux oracle. It never
builds a command package during a case. The selected versions and case IDs for
the current release are recorded in
[`tests/release_runner/current/published.json`](../tests/release_runner/current/published.json).
The next release is prepared through
[`tests/release_runner/current/candidate.json`](../tests/release_runner/current/candidate.json),
generated from the reviewed registry and local module versions. Earlier
published manifests are preserved under `tests/release_runner/historical/` and
require `--historical-replay`. Their frozen corpus and registry sidecars retain
the original source identity; replay does not recreate historical acceptance.
`latest`, version ranges and implicit package resolution are forbidden.

The release manifest must cover every published command (78 commands; the
`timeout` package remains local-only), and every option/operand form promoted in
this record must have positive, boundary, failure and side-effect cases. Help
and version text use contract comparison where project branding differs from
GNU; bytes, status, final newlines and version tokens remain checked. Policy
authorization is separate and continues to run through `moonrun --policy` in
the unified runner.

For every release, update the package version, command README, release
manifest and case coverage together. Validate the generated candidate before
publication. Exact candidate execution additionally requires verified registry
receipts through `--verify-candidate`; preparation alone does not authorize
publication. Use the current published pointer for subsequent consumer checks.
The consumer driver inserts `--` after the exact MoonX coordinate so the
command's own leading `--` is preserved.

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target native tests/release_runner -- \
  --manifest tests/release_runner/current/candidate.json --suite validate \
  --report-dir test-reports/release-candidate-validation
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target native tests/release_runner -- \
  --manifest tests/release_runner/current/published.json --suite smoke \
  --report-dir test-reports/release-published-smoke
```

Historical differential replay requires a sealed immutable oracle profile,
verified image digest, version inventory and reviewed recipe checksums. Prepare
the profile using the [workspace runner guide](../tests/runner/README.md#upstream-and-ci)
before running this example with the verified image ID and a fresh report directory:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target native tests/release_runner -- \
  --manifest tests/release_runner/historical/published-0.2.0.json \
  --historical-replay --suite differential \
  --oracle-image "sha256:<verified-image-id>" \
  --oracle-profile test-reports/oracle-profile/profile.json \
  --report-dir test-reports/release-historical-differential
```

The [release runner guide](../tests/release_runner/README.md) documents exact
registry receipts, candidate verification, publication freezing and report
requirements. These examples do not establish new publication or differential
acceptance evidence by themselves.

Asset/registry transport errors, candidate failures, oracle failures,
semantic mismatches, side-effect violations, timeouts and runner failures are
reported separately. Asset or infrastructure failures are hard failures, not
skips. macOS and Windows use the same exact-version published smoke suite;
only the pinned Linux oracle result promotes a strict differential claim.
HTTP cases use a shared pure-MoonBit loopback fixture. Published HTTPS contracts
reuse the fixed certificate fixture through the testkit on POSIX hosts and are
recorded as platform skips on Windows, where that host fixture is unavailable.
The Windows smoke profile explicitly records POSIX-only permission and symbolic
link cases as `skipped_platform`; Linux/macOS run those cases, and the pinned
Linux oracle remains the strict filesystem authority.

## Inventory

The workspace contains **79 command modules**, with **78 published** and local-only `timeout`. Published command versions are **39 at 0.2.1, 5 at 0.2.2, 3 at 0.2.3, 15 at 0.1.1, 15 at 0.1.2 and 1 at 0.1.3**. Shared `cli/core` is **0.7.0** and is not counted as a command.
Exact coordinates and selected cases are in [the current manifest](../tests/release_runner/current/published.json) and [stage 0 release report](reports/2026-10-20-stage0-release/README.md). Earlier manifests remain historical records under `tests/release_runner/historical/`.

`timeout` is intentionally local-only because portable
`ProcessGroupCancellation` is unavailable:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target wasm --release commands/timeout -- 1s printf ok
```

is a valid local invocation, while `moonx cli/timeout` is not a supported
registry invocation. Earlier package versions and their measured results remain
in the frozen manifests and historical reports.

Status vocabulary: `subset verified` is a successful normal-path probe;
`restricted` additionally needs explicit Wasm file/process/network/permission
policy; `verified rejection` is a boundary exercised and rejected before
claiming success; `local-only` is absent from MoonX by design.

## Per-command support

| Command | Status | Measured profile | Observed boundary or open evidence |
| --- | --- | --- | --- |
| `fold` | subset verified | Byte/control-column folding, width, space breaks, files/stdin | C-locale profile; verify UTF-8 separately |
| `strings` | workspace candidate | Streaming 7/8-bit extraction, TAB, decimal/octal/hex offsets, -o/-t precedence, filenames/stdin markers and selected output separators | Wide/object/Unicode/locale modes remain; unsupported encodings reject before processing |
| `column` | subset verified | Default grid/-x, -c/COLUMNS, -t/-s/-o, empty fields, multiple files, final LF and table ANSI widths | C-byte display profile; full util-linux grammar and automatic terminal width remain |
| `which` | subset verified | Direct/PATH executable access, -a/-s, POSIX separators, empty/duplicate PATH entries and Windows PATHEXT | Shell aliases/functions are not visible; platform permission results follow the public access API |
| `date` | subset verified | UTC/TZ, fixed offsets, checked 64-bit TZif/POSIX future rules, ISO local input, fractional epochs, selected ISO/RFC/format directives | Ambiguous/nonexistent local times reject; relative dates/additional directives and clock setting remain; x/time offset bounds are documented |
| `od`, `hexdump` | workspace candidate | Frozen Linux float formats, od strings/traditional offsets, custom hexdump format/color units, partial elements and final offsets | Non-C/native-ABI equivalence is unclaimed; hexdump forward stdin skip is a documented extension, not util-linux pipe parity |
| `md5sum`, `sha1sum`, `sha512sum` | workspace candidate | Incremental hashes, tags, GNU escaped/tagged check records and manifest flags | Windows text transformation remains outside the selected C byte profile |
| `sed` | subset verified | BRE/ERE substitution, captures, addresses/ranges and ordered scripts; unpublished 0.2.0 adds hold/branch/group/multiline/text execution and repeated nullable captures | [Workspace candidate scope](#workspace-matcher-and-sed-candidates) retains project diagnostic formatting and script-controlled space growth; current-revision acceptance, in-place editing and complete GNU grammar remain open |
| `diff` | workspace candidate | Normal/unified/context output, selected C-byte whitespace/case rules and recursive directory/new-file modes with 0/1/2 statuses | Distinct directory device numbers need public metadata; full GNU grammar and every ambiguous alignment choice remain outside the selected scope |
| `patch` | workspace candidate | Unified/context offset/fuzz matching, reverse detection, partial success, dry run and new reject files | Existing target/named-output mode preservation and existing-reject replacement retain their public-API boundaries |
| `split`, `csplit` | workspace candidate | Selected chunk/line-byte/filter layouts and suffix starts/elision; integer csplit suffix formats, suppress-matched boundaries, cleanup and keep-files | Existing outputs refuse until safe identity/truncation effects are established; remaining resources and [matcher limits](#workspace-matcher-and-sed-candidates) stay explicit |
| `expr` | subset verified | Integer/string expressions and BRE matches; unpublished 0.2.0 uses the shared capture matcher | C-byte locale; [matcher limits](#workspace-matcher-and-sed-candidates) and remaining expression extensions are project work |
| `fmt` | subset verified | Unpublished 0.1.2 adds crown/tagged margins and prefix matching to width/goal/spacing optimization | C-byte locale; paragraph resources, PR/main and non-C width acceptance remain separate |
| `gzip`, `gunzip`, `zcat` | subset verified | Unpublished 0.1.2: pure 32 KiB LZ, 3–258 byte matches, stored/fixed/dynamic costs, `-1`–`-9` and aliases; Reader decoding with 64 KiB input/output, 32 KiB history and main/secondary tables preserves members, CRC and error prefixes | Published 0.1.1 keeps its frozen profile. [G1 development evidence](reports/2026-10-24-g1-codec.md) covers GNU roundtrips and selected size limits; 30 codec tests pass Native/Wasm. Published delivery/performance remain open. Bytes callers retain input; levels are ignored during decoding/testing. Named replacement and saved metadata remain boundaries. |
| `base32` | subset verified | RFC 4648 uppercase encode/decode, `-d`, `-i`, `-w`, stdin or one file | Nonstandard alphabets and locale diagnostics not claimed |
| `cksum` | workspace candidate | POSIX/legacy and selected modern algorithms/lengths, tagged/untagged/base64/raw records and manifest checking | C byte profile; Windows text translation and final publication are not inferred |
| `expand` | subset verified | C-locale tab expansion, `-i`, `-t` stops, stdin or multiple files | Locale display widths and non-byte tab semantics are not claimed |
| `base64` | subset verified | `-d/-D`, `-i/--ignore-garbage`, `-w N`, file and stdin encode/decode | Nonstandard alphabets and locale diagnostics not claimed |
| `basename` | subset verified | `-a`, `-s SUFFIX`, `-z`, empty/root/repeated-separator operands | Full multibyte path locale behavior not claimed |
| `cat` | subset verified | files/stdin; `-n -b -s -A -E -T -v -e -t`, `-u/--unbuffered` | Unbuffered is a stream-safe compatibility no-op |
| `chmod` | subset verified | Numeric modes, closed symbolic assignments, command-line symlink following, recursive symlink skipping | Incremental/implicit symbolic modes need public mode reads; full recursive command-line directory-symlink combinations remain unverified |
| `cmp` | workspace candidate | equal=0, different=1, error=2; `-s -l -n -i -b/--print-bytes`, C octal/visible byte notation and EOF distinctions | Non-C locale and every diagnostic form remain outside the selected evidence |
| `comm` | workspace candidate | Three columns, `-123`, `-z`, last order policy, custom output delimiter, totals including suppressed columns | Locale collation beyond C bytes not claimed |
| `cp` | subset verified | `--no-preserve=mode` to new regular files/trees; no-clobber/update no-ops; traversal controls | Default source-mode preservation and every existing regular-file overwrite reject until public mode/identity/handle-truncate APIs exist; same-inode aliases remain intact |
| `curl` | subset verified | Existing HTTP/HTTPS transfer profile plus Basic `-u`, literal/Netscape `-b`, `-c`, redirect cookie state and credential origin boundaries; 0.2.1 sends separate explicit/jar Cookie fields | Literal cookies remain scoped to the initial origin as in pinned curl 8.22.0. No non-Basic auth/password prompts/PSL/IDNA/raw Set-Cookie input files; 0.2.1 includes the explicit Cookie plus jar correction |
| `cut` | workspace candidate | Byte/field ranges, complement, custom output delimiter, empty/NUL delimiters, `-s/-z` | Locale/multibyte behavior not claimed |
| `dirname` | subset verified | multiple operands and `-z`, empty/root/repeated-separator operands | Multibyte path locale behavior not claimed |
| `echo` | subset verified | `-n`, `-e`, `-E`, byte escapes, literal `--` ambiguity | `POSIXLY_CORRECT` profile not claimed |
| `env` | workspace candidate | Complete inherited environment, `-i/-u/-0/-C`, GNU split-string quoting/expansion/splicing and direct children | No host-shell interpretation; host authorization and child launch error classes remain separate |
| `false` | subset verified | any args: no output, status 1; help/version return 0 | Metadata text is package-versioned |
| `find` | restricted | names/paths/types, `-empty/-size`, metadata predicates, access checks, `-xtype`, depth/actions | File/process policy required; P8 time/reference/access combinations still need independent probes; ownership, inode, link-count, and full GNU expression grammar not claimed |
| `grep` | subset verified | Default BRE / `-G`, ERE / `-E`, byte-based `-F`, `-o` leftmost-longest, context-only separators, existing context/file/binary options; unpublished 0.3.0 adds the shared matcher, grammar-preserving ASCII `-i`, streaming input/output and early `-q`/`-l` completion | [Workspace matcher limits](#workspace-matcher-and-sed-candidates), non-C locale classes/case folding and worst-case capture/reference resources remain open |
| `head` | subset verified | `-n`, `-c`, signed/attached/long/legacy counts and decimal/binary/IEC size suffixes, `-z`, `-q/-v`, files/stdin and headers | Counts are bounded by signed 64-bit storage; locale-aware records are not claimed |
| `join` | workspace candidate | Field/unpaired/empty output, `-z`, ASCII ignore-case, headers, automatic or accumulated explicit output fields, last order policy | Locale behavior beyond the fixed C profile not claimed |
| `jq` | subset verified | Consecutive JSON, -s/-R/-n/-e, AST binding, partial output before errors, -C/-M/JQ_COLORS, tostring/tojson and Unicode string slices | Released moonjq 0.2.0 plus public-AST adapter; full evaluator/modules/streaming/diagnostics and automatic TTY color are not claimed |
| `jqlog` | subset verified | JSONL stdin/raw input, -f/-h, invalid-line skipping, conversions and Unicode slices | Independent JSONL contract; invalid whitespace lines are not repaired by trimming; full jq CLI compatibility is not claimed |
| `ln` | subset verified | Symbolic -s/-r, last -f/-i selection, -n/-T/-t, backup/suffix/-v and refusal status 1 including EOF | POSIX symlinks; hard-link requests reject before mutation; broader overwrite/target combinations remain |
| `ls` | workspace candidate | Existing traversal/sort/link profile plus C quoting, columns/across/commas, width/tab stops and explicit type/suffix/link colors | `-P` is a project extension; enabled raw-mode/capability/link-count predicates and automatic color reject. Long/ownership/inode/block formats remain outside scope |
| `make` | subset verified | Real `-j` dependency scheduling, shared prerequisites once, failed-dependency propagation, `-k`, `$(shell ...)`, `.SHELLSTATUS`, cwd and exported recipe variables | No GNU jobserver/full Make grammar claim; shell-function export recursion and full GNU variable semantics remain project work |
| `mkdir` | workspace candidate | `-p`, numeric and umask-independent symbolic `-m`, requested leaf mode and existing no-ops | Truly umask-dependent results, unknown parent raw mode/owner adjustments and unavailable Windows setters reject |
| `mktemp` | workspace candidate | Final X-run/default/inferred/explicit suffix rules, tmpdir precedence, quiet errors and exclusive secure-random files/directories | No unsafe `-u`; POSIX mode relationships and Windows supported effects have separate scenarios |
| `mv` | subset verified | Files/dirs, -f/-n/-i, -T/-v, selected backup/suffix/update, same-entry/hard-link no-op failures and refusal status 1 | Equal-time interactive/update targets reject without public identity; no-clobber remains a successful skip; metadata-preserving EXDEV fallback remains unavailable |
| `nl` | subset verified | `-b/-h/-f`, `-w`, `-s`, `-v`, `-i`, `-d`, `-p`, files/stdin | Locale-aware formatting not claimed |
| `paste` | subset verified | parallel/serial `-s`, delimiter cycling `-d`, `-z` | Full malformed delimiter diagnostics not claimed |
| `printenv` | subset verified | selected/all values and `-0`, mixed present/missing status | Wasm environment is policy-dependent |
| `printf` | subset verified | Unpublished 0.2.2 adds exact frozen-ABI hex floats and C-byte GNU `%q` to format reuse, flags and numeric conversions | Fixed Linux amd64 numeric profile; non-C locale and every GNU diagnostic not claimed |
| `pwd` | subset verified | `-L`, `-P`, invalid logical `PWD` fallback | Logical/physical result follows Wasm cwd contract |
| `rm` | workspace candidate | Files/trees, explicit per-entry/once interaction, last force/interactive policy, iterative prompt order and root-preservation flags | Automatic terminal-dependent write-protection prompts need public terminal/raw-mode metadata; final dot/dot-dot operands reject |
| `realpath` | workspace candidate | Component-wise default/-e/-m, strip/no-symlinks, relative-to/base, quiet/NUL and ordered operands | Only unresolved physical link targets need readlink; lexical missing paths do not |
| `rev` | workspace candidate | Ordered C-byte line reversal from stdin/multiple files with exact partial-error/LF behavior | Multibyte locale character semantics remain outside the C profile |
| `rmdir` | subset verified | empty removal, `-p`, `-I`, `-v`, failure ordering | Full path diagnostics not claimed |
| `seq` | subset verified | Unpublished 0.2.3 adds single-conversion `-f`, frozen-ABI rounding and endpoint recovery; default +/- step, -w/-s and streaming output remain | Default path retains 4096-character/exponent/scale limits; formatted path uses the selected Extended80 range, not the host ABI; formal performance remains open |
| `sh` | subset verified | Persistent `-i` line REPL and opaque Session; export/local variables, cwd, quoting/IFS/glob, arithmetic, substitution, read, bounded printf/test, functions and pipeline state isolation | No public isatty/raw/editing/recoverable SIGINT/job control/exec; remaining interpreter grammar restrictions are project work, listed in command README |
| `sha256sum` | workspace candidate | File/stdin digest, tags, escaped/tagged manifests and quiet/status/strict/warn/ignore-missing verification | Windows text transformation remains outside the selected C byte profile |
| `sleep` | subset verified | fractional values, `s/m/h/d`, multiple operands, help/version | Signal/cancellation parity not claimed |
| `sort` | subset verified | Unpublished 0.2.2 adds stable/merge/output and exact seeded GNU random order to cached keys and bounded disk runs | Existing merge-output identity/error effects reject explicitly; non-C locale and formal RSS/performance remain open |
| `tail` | workspace candidate | Existing line/byte/origin/follow profile plus NUL records, final terminators and ordered file headers | `-f` follows open descriptors; stdin/pipes stop at EOF; `-F` path-follow and rotation reopen remain outside scope |
| `tac` | workspace candidate | Ordered reverse records, fixed or GNU Emacs byte-regex separators, before mode and nullable/overlap selection | Non-C locale and formal remaining whole-input/index resources remain open |
| `tee` | workspace candidate | stdin to stdout/files, append, five explicit output-error/pipe policies and observed partial/later-sink effects | Default SIGPIPE termination needs a released restore/raise API and has an exact status-2 rejection scenario |
| `test` | subset verified | string/integer, file kinds, access, regular-file size, `!`, `-a`, `-o`, and the exercised dangling-link path | `-N`/`-nt`/`-ot` and special-file positive fixtures need independent probes; complete unary/binary ambiguity not claimed |
| `tree` | workspace candidate | C text/JSON/safe HTML, iterative filters/prune/filelimit, explicit colors, actual public sizes and postorder disk-usage reporting | Linux directory size is supported; observed macOS directory size rejects and Windows follows its API result. Selected symlinks/raw-mode colors need readlink/mode; HTML page differences are deliberate |
| `timeout` | local-only | local duration and expiry returned 124 | No published process-group cancellation |
| `touch` | subset verified | Create missing files; `-c` missing-file no-op | Existing-file timestamp updates and setters explicitly fail without content rewrites |
| `tr` | subset verified | translate/delete/squeeze/`-c/-C` complement, `-t`, ranges, C-locale classes, octal/equivalence/repetition forms | Verified profile is byte-oriented; locale data beyond C is not claimed |
| `true` | subset verified | any args: no output, status 0; help/version | Metadata text is package-versioned |
| `uniq` | workspace candidate | Adjacent filtering, counts, selected repeated/unique members, all-repeated/group separators, `-i/-f/-s/-w/-z` | Fixed C-byte comparisons; non-C collation not claimed |
| `unlink` | subset verified | Exactly one regular-file/symlink operand, -- separator, help/version | Extra operands reject before any deletion; directories reject |
| `unexpand` | subset verified | Leading/all blank conversion, `--first-only`, `-t` stops, stdin or multiple files | Locale display widths and non-byte tab semantics are not claimed |
| `wc` | workspace candidate | C-byte counters, display width, four total policies, `--files0-from`, partial read-error counts, files/stdin | Non-C counters and regular-stdin physical-fstat alignment are not claimed; see ADR-0003 |
| `wget` | subset verified | Existing transfer profile plus challenge-based Basic credentials across destinations; `--auth-no-challenge` sends explicit credentials on every request, including redirects; load/save cookies, session-cookie option, shared redirect jar; 0.2.1 lets explicit Cookie override stored cookies | No recursive mirror/FTP/HSTS/PSL/IDNA; consumed stdin bodies cannot replay an auth challenge; cross-port and cross-operand authentication caching and full progress text not claimed; explicit Cookie override is delivered in 0.2.1 |
| `yes` | subset verified | Infinite repeated `y` or joined arguments, help/version, broken-pipe termination | Exact signal diagnostics and terminal interaction are not claimed |
| `xargs` | workspace candidate | Existing batching/process windows plus raw delimiter grammar, last -0/-d selection and separately opened interactive confirmations | Child policy remains required; invalid-byte argv needs public byte transport, and unavailable independent confirmation channels reject before input/launch |
| `xxd` | workspace candidate | Styles/autoskip/group/case/EBCDIC, wide named-file seeks, forward stdin discard, reverse address adjustment and new named output backpatching | Existing-output identity/mode/content and backward/end-relative stdin seek retain narrow public-API limits |

## Help-Visible Only

The following options appeared in the current Wasm `--help` output but are not
called “supported” above because this audit did not exercise a complete
positive result. They are probe targets, not product claims.

| Command | Help-visible only |
| --- | --- |

Each row identifies the option families exercised successfully. Explicit
rejections, including `chmod` incremental/reference modes,
`cp -a/-p`, `ln` hard links, truly umask-dependent `mkdir` modes, existing merge
outputs for sort, timestamp selectors for `touch`, and unseekable backward
stdin positions are recorded in their rows. The portable filesystem profile
exposes file kind, platform-supported size metadata, a/m/c times,
access checks, and symlink creation; mode reads, timestamp setters, hard links,
readlink and special-file creation remain closed. POSIX EXDEV classification
is available; metadata-preserving cross-device fallback is not.

## Cross-cutting runtime rules

Ordinary filter stdin remains silent. The explicit `sh -i` session instead
emits PS1/PS2 on stderr and executes each complete input without waiting for
EOF. Script mode emits no prompts. The successful quiet paths for `curl`
and `wget` produced no stderr in this audit. Dynamic meter behavior and
non-terminal progress formatting remain unverified.

Wasm policy is part of the observable invocation. Paths outside policy roots,
child programs outside `process.allow`, or endpoints outside network policy
fail with nonzero status. That is an authorization result, not evidence that a
parser or transformation is absent.

## Reproduction rule

Build native and Wasm artifacts once, then pass their build roots to the
unified runner. The runner creates isolated directories, captures stdout,
stderr, exit status, and side effects independently, and applies network policy
only in the policy suite. Record positive and negative cases together. Update
this record and the command README only after native semantics, the applicable
pinned oracle cases, and Wasm policy checks are repeatable.

Per-command decisions are in [`docs/adr/README.md`](adr/README.md). Historical
source provenance and upstream version pins remain in
[`docs/provenance.md`](provenance.md) and [`docs/upstream-baselines.md`](upstream-baselines.md).
