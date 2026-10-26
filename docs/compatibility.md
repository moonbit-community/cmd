# Command Support Record

Date: 2026-09-05
Updated: 2026-10-26

Current delivery acceptance targets Wasm through MoonX on Linux, macOS and
Windows. Native implementations may remain compilable, but Native command tests
and backend pairing are no longer delivery gates. Dated Native observations
below retain their historical meaning. See [Wasm CI migration](ci-wasm-migration.md)
for development checks and separate manual release/resource workflows.

The 2026-10-25 R release uploaded `cli/core@0.8.1` and seven changed command
packages. The other 71 command versions and all dependency declarations remain
unchanged, including the mixed core 0.7.0/0.8.0 coordinates. `timeout` stays
local-only. The [R release summary](../CHANGELOG.md#2026-10-25) records the
serial uploads and local MoonX acceptance of all 78 latest command coordinates.
The 2,135-case run recorded 1,875 semantic passes,
186 availability passes, 52 explicit boundary results, 22 platform skips and
zero failures. Ten supplemental functional checks passed for find, test and
yes, completing functional coverage beyond metadata/availability for all 78
commands. This release does not claim new
cross-platform acceptance or completion of formal performance work.

There are **80 local command modules and 78 published commands**. Local
`rg 0.1.0` and catalog-only `core 0.8.2` are unpublished candidates; `timeout`
is local-only.
Published command versions are **37 at 0.2.2, 8 at 0.2.3, 3 at 0.2.0,
2 at 0.2.1, 12 at 0.1.3, 10 at 0.1.2, 4 at 0.1.4, and one each at
0.2.4 and 0.3.0**. Shared `cli/core` is **0.8.1**
and is not counted as a command.

The [stage 0 release](../CHANGELOG.md#2026-10-20),
[metadata release](../CHANGELOG.md#2026-10-18)
and [fidelity repair](../CHANGELOG.md#2026-10-11) remain
historical evidence for their original coordinates. Their summaries are in the changelog; original reports remain in Git history,
and frozen published expectations remain unchanged.

Authorization belongs to the caller/host. Catalog capabilities and the
restricted label describe requirements, not command-local policy.
Split is Restricted because `--filter` can launch external children; the
current tier counts and command list are recorded in [ADR-0002](adr/0002-policy.md).

## Published R resource changes

Column/rev/tac **0.1.4**, csplit/diff **0.2.1**, split **0.1.3**, sort **0.2.3**
and core **0.8.1** are published. Dependency versions remain unchanged. The
[R release summary](../CHANGELOG.md#2026-10-25) records the serial uploads
and exact-version local MoonX acceptance separately from the earlier
[implementation summary](../CHANGELOG.md#2026-10-25).

| Command | Storage and output contract | Retained boundary |
| --- | --- | --- |
| rev | One input record and a record-sized reversed buffer, with 64 KiB input/output buffers; accepted records flush when the output buffer fills, at EOF or after an input error. | The fixed Linux C profile rejects non-ASCII records; storage follows the longest record. |
| split | Byte/line modes stream; total-dependent modes measure regular files or spool; line-byte mode spools its pending prefix. Round-robin ordinary files close between records. | Piece names/state are O(visited pieces); round-robin filters retain one pipe/task per visited piece and their children have separate costs. Existing outputs still refuse. |
| csplit | One input snapshot plus a disk index of 64-bit line boundaries; two caches of at most 64 KiB, a current regex line and created-output paths. Input/spool failure precedes fragment creation. | Disk is input bytes plus eight bytes per boundary. Regex-line indices and numeric patterns/offsets retain signed 32-bit limits; `-k` controls retention of owned fragments after later failure. |
| tac | Fixed separators use backward 64 KiB reads and bounded overlap; stdin/nonregular/regex input spools before output. | Regular files can change concurrently. Regex requires O(input) memory and signed 32-bit matcher indices until a paged/seekable shared matcher is implemented and verified; no fixed overlap truncates arbitrary spans. |
| column | Two-pass layout uses one displayed-record snapshot and disk index; no reopened input or complete output string. First output follows the attempted input pass. | Disk is displayed bytes plus sixteen bytes per record; memory includes the longest record, table widths and fixed buffers. Table/small-grid caches use at most 1 MiB data pages and 64 KiB index pages; wide grids grow on demand to at most 256 pages per cache (16 MiB data plus 1 MiB index). Late read errors preserve complete records; output failure may retain a prefix. |
| sort | `-S/--buffer-size`, repeated `-T/--temporary-directory` and `--batch-size` control accounted run storage and merge fan-in, capped at sixteen. The default remains 64 MiB. | The budget is not an RSS cap and allows an oversized record. `0%` selects the minimum budget; nonzero percentage sizes reject before input effects until a public physical-memory-capacity query and rounding/overflow regressions exist. |
| diff | Records borrow byte views from buffered inputs; unchanged comparison keys reuse those bytes and edit reconstruction retains O(N+M) auxiliary space. | Complete inputs, record indexes, transformed keys and edit/output records remain resident; this is not constant-memory diff. |

Column, csplit and tac's spooled modes require temporary write access, which the
catalog declares alongside sort and split. Invocation-owned temporary paths are
exclusive and removed on success, ordinary errors and runtime-observable
cancellation; SIGKILL and machine failure cannot guarantee cleanup. Preserve
actual byte/status/effect and resource observations separately from source
contracts and final platform acceptance. The [streams ADR](adr/0003-streams.md#r-streaming-and-temporary-storage-contracts)
records the choices, limitations and unlock conditions.

## Published O5-O13 option profiles

The selected O-stage implementations are now published; the registered cases
and package tests describe current source behavior. Private Native/Wasm
comparisons remain development evidence. Current local MoonX acceptance is
recorded in the dated release summary above; formal direct-Wasm resources/performance
remains pending. Tree uses directory
sizes only when its released public
backend actually returns them; no portable inode-size constant is assumed.

| Family | Current source behavior | Retained boundary |
| --- | --- | --- |
| split | All selected byte/line/round-robin `-n` forms, `-C`, suffix starts/growth, elision and pure MoonBit `--filter` sessions with `$FILE`, stdin and observed child status. | Restricted: external filter children require host process authorization. Ordinary existing outputs still reject. GNU's undefined hexadecimal FROM=a-f indexing is excluded; the workspace uses documented base-16 arithmetic. |
| csplit, rev, tac | Csplit integer suffix descriptors and suppress-matched offsets; ordered rev/tac operands and tac's GNU Emacs C-byte regex selection. Rev follows frozen Linux C ASCII/NUL handling and rejects non-ASCII records before writing them. | Existing csplit outputs and Windows generated names ending in spaces/dots reject. New R snapshots, reverse reads and the regex memory limit are recorded above, separately from published option acceptance. |
| od, hexdump, cmp, strings | Frozen Linux numeric formats, strings/traditional od offsets, custom hexdump formats/color rules, cmp byte notation and strings separators. | Wide strings encodings remain rejected. Hexdump forward stdin discard is an explicit extension: util-linux 2.40 rejects seek on a pipe, while equivalent named-file display supplies the byte reference. |
| xxd | Autoskip/style/group/case/EBCDIC, wide named-input seeks, forward stdin discard, reverse address adjustment and new named outputs with backpatching. | Existing output alias/mode/content preservation needs public file identity and descriptor operations; backward/end-relative stdin positioning needs a seekable public input. |
| checksum commands | Cksum algorithm/length selection, modern tagged/base64/raw records and checking; consistent tags, escaping and manifest flags for the four sum commands. | The selected C byte profile does not claim Windows text translation. Public digest implementations and bounded incremental state remain shared. |
| realpath, mktemp, mkdir, rm | Component-wise missing/strip/relative realpaths, GNU temporary templates/tmpdir/suffix/exclusive creation, umask-independent symbolic directory modes including GNU sticky-clause finalization, and explicit once/per-entry removal prompts. | Unresolved physical link targets need readlink. Umask-dependent modes, unknown parent raw mode and unsupported Windows setters reject. Automatic terminal-dependent rm prompting is separate from implemented explicit prompts. |
| ls | C quoting/layout/tab width and explicit color with type/suffix/link-target selection, preserving raw color bytes. | Color auto detection rejects; enabled mode/capability/link-count predicates reject only relevant entries. Effective access is not GNU's raw execute-bit predicate. |
| tree | Iterative filtered/pruned JSON/HTML/text traversal, safe escaping, C branches, explicit type/suffix color, selected sizes and postorder disk-usage totals. | Public directory size works on Linux and fails on the observed macOS backend; Windows uses the real API result. Readlink and raw-mode color predicates retain narrow boundaries. HTML page metadata/safety differences are deliberate contracts. |
| env, xargs, tail, tee | Env split-string grammar/expansion/splicing; byte delimiters and separate xargs confirmation input; tail NUL records; tee's five explicit pipe-error policies with actual closed-pipe scenarios. | Windows Native empty child environments reject until released async fixes its environment block; enumeration and nonempty assignments work. Invalid-byte argv needs public byte transport. Unavailable confirmation channels reject before argument input. Default tee SIGPIPE termination needs a released restore/raise API; it reports status 2 rather than a fabricated signal result. |

The four former od-float, hexdump-format/stdin-skip and md5sum-tag boundary IDs
now bind positive regressions. New explicit boundaries retain their rejection
cases and unlock conditions in the canonical ADRs. Generated mktemp scenarios
observe name/type/content/mode relations; closed-stdout tee scenarios observe
status, stderr and later file effects without claiming captured stdout.

## Published sorting and formatting profiles

Sort **0.2.2**, seq **0.2.3**, printf **0.2.2**, fmt **0.1.2** and
expand/unexpand **0.1.3** add the selected sorting, numeric-format, paragraph
and tab-grid families. Shared numeric, C-byte shell quoting and tab-stop code
selects core **0.8.0**. These coordinates are published. Current source and
private Native/Wasm GNU observations remain separate from the completed local
MoonX acceptance and pending formal performance work.

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

## Published text-option profiles

Cut, uniq, comm, join and wc **0.2.2** add the selected complement,
delimiter, duplicate-group, merge-header/field and total policies. Their current
PR #52 and actual-main run 40110917627 passed the then-required platform and
coverage checks. Coverage audits are now retired. These coordinates are published; local MoonX
acceptance is recorded in the dated release summary above. The exact contracts are in the current case
corpus and [streams ADR](adr/0003-streams.md).

Wc -m now follows the selected C byte profile, including invalid UTF-8, and
no longer maintains a UTF-8 decoder. Named-file widths follow size metadata;
multi-counter stdin uses stream-width padding. Exact GNU physical-fstat width
for regular-file redirection to stdin remains a public descriptor-metadata
limit, independently of total-only output and counter correctness.

## Published diff and patch profiles

Published diff **0.2.1** and patch **0.2.0** select core **0.8.0**. Diff adds C-byte
case/whitespace/blank/CR comparisons and ordinary directory workflows with
recursive, new-file and unidirectional-new-file modes. Comparison keys are
separate from displayed records; `--strip-trailing-cr` also strips the CR from
displayed LF-terminated lines. Edit reconstruction uses linear auxiliary
frontiers and an explicit work stack. Unchanged keys share input byte views;
transformed keys, indexes and edit/output records remain resident alongside
the complete inputs. This is not constant-memory or linear-time diff.
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
user on 2026-10-24. MoonX launcher cost is outside that gate. Publication does
not establish formal performance acceptance. Local MoonX acceptance of the
current coordinates is recorded in the dated release summary above.

## Published stream implementations

Core 0.8.0 uses a reusable 64 KiB line scanner. Comm, cut, head, join, jq, nl,
paste, sed, sort, uniq and xxd select that published core coordinate.
Cat reuses a 64 KiB copy buffer, wc computes selected counters, and strings
streams accepted printable runs. Accepted options and byte profiles remain.
Head batches output in 64 KiB blocks. Cp selects core 0.8.0 for new-file
copying; mv **0.2.4** also selects that coordinate. Mv uses rename and has no
copy-and-delete fallback. Existing filesystem capability boundaries remain.
Sort caches comparison transformations and uses stable disk runs under a
64 MiB accounted run budget with at most sixteen merge inputs. This budget
does not include all allocator/GC or oversized-record costs and is not an RSS cap.
The [development observations](../CHANGELOG.md#2026-10-24) record
local correctness and timing separately from formal resources/performance.
The [current release summary](../CHANGELOG.md#2026-10-25) records
publication and completed local MoonX acceptance.

## Published matcher and sed profiles

The matcher implementation was published in core **0.8.0**, grep **0.3.0**,
and sed/expr/csplit **0.2.0**. Core **0.8.1** and csplit **0.2.1** retain it.
Their current local MoonX acceptance is recorded in the dated release summary above.
[PR #49](https://github.com/moonbit-community/cmd/pull/49)
merged the S implementation after all required platform and coverage checks.
The [S implementation summary](../CHANGELOG.md#2026-10-24) records its
development evidence. Publication is recorded in the
[current release summary](../CHANGELOG.md#2026-10-25); formal
performance remains separate.

The shared C-byte matcher parses BRE/ERE once, supports the tested byte classes,
word assertions and pattern backreferences, and exposes span-only search
to grep. Csplit and sed regex addresses use a capture-free predicate; expr and
sed substitutions request capture registers, following GNU's distinct calls.
Grep's ASCII `-i` expands literals/classes before class negation,
preserves assertion escapes and compares references without changing captured
bytes. Tac adds its distinct GNU Emacs syntax; nl retains its
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
oracle and coverage evidence for its scope; current local MoonX acceptance
is recorded in the dated release summary above and formal performance remains pending.

## Accepted stage 0 subset: async 0.22.5

[Roadmap stage 0](../docs/compatibility.md) was accepted for core 0.7.0 and
curl/mv/wget 0.2.3. The following implementation decisions and acceptance
contracts retain their original [stage 0 release evidence](../CHANGELOG.md#2026-10-20).
Broader API, host and command-feature
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

## Validation and metadata

The current [development workflow](../.github/workflows/check.yml) runs
release Wasm commands and package tests on Linux, macOS and Windows. Native
is used for test tools. The shared [runner](../tests/runner/README.md) builds
no command during a case; it captures bytes, status, filesystem effects and
process observations from prebuilt artifacts. Host authorization is tested
separately from command semantics. Missing infrastructure, empty selections,
timeouts and uncertain cleanup are failures, not semantic passes.

Standalone `--help` starts with `Usage: <command>`, includes help/version
options, ends with a newline and exits 0 on stdout. Standalone `--version`
prints exactly `<command> <package-version>\n`, with empty stderr and status
0. Both return before reading input. The current observer passes an inherited
stdin sentinel and verifies that it remains unread; older closed-stdin
captures do not establish this property. All 80 workspace commands are selected.

From the repository root:

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target wasm --release --deny-warn
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target native --deny-warn tests/runner
MOON_HOME="$HOME/.moon-accounts/cli" ./_build/native/debug/build/mooxCLI/cmd-tests/runner/runner.exe --suite functional --report-dir test-reports/local-functional
```

Use a fresh report directory. `contract`, `metadata`, `scenarios`, `policy`,
`compat` and `stress` support focused diagnosis; `functional` combines the
applicable correctness suites. Linux `all` additionally requires the current
verified immutable oracle profile. A focused run is not full acceptance.

## Published-version verification

[latest.json](../tests/release_runner/current/latest.json) selects the 78 exact
published coordinates and independent `latest-cases.json` expectations.
`candidate.json` selects reviewed workspace versions and `active-cases.json`.
`published.json` and the historical manifests retain older frozen meanings.
The current driver does not implement the retired historical-replay,
receipt-verification or publication-freezing protocols. Git retains those
older implementations; historical records are not current execution inputs.

The manual [release workflow](../.github/workflows/release-acceptance.yml)
executes exact MoonX coordinates on all three hosts, plus the pinned Linux
comparison. It never publishes or rewrites manifests. Every product child
uses the same selected coordinate map; startup and acceptance run serially.
`functional` is the default, `oracle` selects comparison and Linux `all`
combines them. Legacy `smoke`/`differential` alias `functional`/`oracle`.

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target native --release --deny-warn tests/runner tests/release_runner
MOON_HOME="$HOME/.moon-accounts/cli" ./_build/native/release/build/mooxCLI/cmd-tests/release_runner/release_runner.exe --manifest tests/release_runner/current/latest.json --suite functional --report-dir test-reports/published-functional
```

The wrapper inserts `--` after the exact MoonX coordinate. Candidate
generation is preparation only; it authorizes no upload. Publication requires
development checks, serialized changed-package uploads and exact-version
three-platform acceptance with Linux comparison. Do not republish unchanged
commands or alter frozen expectations to make a new source result pass.

The 2026-10-26 manual run 40270955851 verified all 78 selected published
coordinates: Linux/macOS/Windows recorded 2,287/2,094/1,961 passes and
15/18/151 explicit platform skips, with zero failures. Linux included the
full pinned comparison. These dated results include startup and boundary
checks; they are not counts of universally supported upstream features.
The subsequent rg candidate is absent from that published selection.

HTTP uses shared loopback fixtures. HTTPS fixture and POSIX metadata cases
retain their explicit platform conditions; a skip is not evidence for the
excluded platform. Resource observations and formal performance acceptance
remain separate manual work. See the [release guide](../tests/release_runner/README.md)
and [changelog](../CHANGELOG.md) for workflow and dated results.

## rg candidate

Updated: 2026-10-26. `cli/rg@0.1.0` and the catalog-only `cli/core@0.8.2` are
unpublished candidates. Existing published command versions and dependencies
are unchanged. Current sources and package tests live in `commands/rg`; executable contracts
are in `tests/cases/rg.json`. Import pins are in the upstream baseline record. The fixed source is rg.mbt 0.2.0
`2727c25819b00ddd1a0e9b24f9cb683931d64edf`; the semantic oracle revision is
`3fce3b5bb0236da2df6d99672afb8a719642eca7`.

Explicit files/directories and `-` for stdin support the imported regex/Unicode,
encoding, glob/ignore, context/replacement, counts, binary/text, multiline,
sorting, JSON and user-selected preprocessing paths. Ordinary search uses
incremental async readers and sinks. Multiline and path sorting retain their
original materialization. Only command behavior is migrated; former library
interfaces are private implementation details.

Effective `-z`/`--search-zip` rejects with status 2 and no stdout. Compression
development is explicitly deferred. The former experiment is retained only in
Git commit `65b4b7eea24c8215776c40721e1e00ad436268ce`; it is not a workspace
dependency or part of the package.
No compression-format acceptance or performance gate is claimed.
`--no-search-zip` and a later `--pre` preserve the imported parser precedence.

| Public capability gap | Executable behavior | Unlock condition |
| --- | --- | --- |
| stdin kind | No-path search exits 2, explaining `specify a path or -`; explicit path/stdin works; `--files` defaults to cwd | Released portable standard-input type API, tested on all three Wasm hosts |
| terminal kind | Auto color/headings choose plain output; explicit color/heading remains available | Released public terminal query; do not infer terminal state from environment |
| device/inode and stdout identity | `--one-file-system` exits 2; redirected-output same-file exclusion is unavailable | Public metadata/descriptor identity with hardlink and race-sensitive regressions |
| readlink and raw paths | No raw-byte path or link-text API is advertised; canonical public realpath detects followed directory loops | Public link-text/raw-path APIs with invalid-UTF-8 and loop fixtures |
| creation time | `--sort created` / `--sortr created` reject unsupported metadata | Released creation-time metadata with per-platform ordering assertions |

The imported implementation remains single-threaded, has no real mmap and has
no PCRE2 engine. `--threads` does not create parallel workers; mmap flags retain
their existing ordinary-read implementation. OS diagnostics retain public
runtime messages rather than fabricated errno translations. Elapsed JSON times
derive from the public millisecond clock and are not CPU/resource measurements.

`--pre` consumes child stdout incrementally, drains stderr concurrently and
reaps the direct child on completion/early close/cancellation. Stderr diagnostic
storage follows the imported accumulated-error API. No process-tree cleanup
promise is made. See [ADR-0006](adr/0006-process.md).

Ordinary Wasm contracts, supplemental Native runs, fixed-upstream harness
observations and sealed Linux oracle results are distinct evidence classes.
Raw upstream cases using implicit input are retained as boundary differences,
not renamed or counted as compatibility passes. The Linux oracle recipe pins
the exact ripgrep source hash, Rust distribution hash and Cargo.lock; only a
current CI-sealed image identity can establish differential acceptance.

## Inventory

The workspace contains **80 command modules**, with **78 published**, unpublished
`rg 0.1.0` and local-only `timeout`. Published command versions are **37 at 0.2.2, 8 at
0.2.3, 3 at 0.2.0, 2 at 0.2.1, 12 at 0.1.3, 10 at 0.1.2, 4 at 0.1.4,
and one each at 0.2.4 and 0.3.0**. Shared `cli/core` is **0.8.1** and is not
counted as a command.
Exact registry coordinates and selected local-acceptance cases are in
[the latest manifest](../tests/release_runner/current/latest.json) and
[R release summary](../CHANGELOG.md#2026-10-25). Local MoonX acceptance
covers all 78 commands, with zero failures and the documented boundaries and
platform skips. The previous frozen baseline stays in
`current/published.json`; earlier manifests remain under
`tests/release_runner/historical/`.

`timeout` is intentionally local-only because portable
`ProcessGroupCancellation` is unavailable:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target wasm --release commands/timeout -- 1s printf ok
```

is a local-only diagnostic invocation, while `moonx cli/timeout` is not a supported
registry invocation. Earlier package versions and their measured results remain
in frozen manifests and Git history, summarized in the changelog.

Status vocabulary: `subset verified` describes the selected tested profile, not all upstream behavior;
`restricted` additionally needs explicit Wasm file/process/network/permission
policy; `verified rejection` is a boundary exercised and rejected before
claiming success; `local-only` is absent from MoonX by design.

## Per-command support

| Command | Status | Measured profile | Observed boundary or open evidence |
| --- | --- | --- | --- |
| `fold` | subset verified | Byte/control-column folding, width, space breaks, files/stdin | C-locale profile; verify UTF-8 separately |
| `strings` | subset verified | Streaming 7/8-bit extraction, TAB, decimal/octal/hex offsets, -o/-t precedence, filenames/stdin markers and selected output separators | Wide/object/Unicode/locale modes remain; unsupported encodings reject before processing |
| `column` | subset verified | Default grid/-x, -c/COLUMNS, -t/-s/-o, empty fields, multiple files, final LF and table ANSI widths; published 0.1.4 uses one indexed disk snapshot | Temporary write access; C-byte display profile, full util-linux grammar and automatic terminal width remain |
| `which` | subset verified | Direct/PATH executable access, -a/-s, POSIX separators, empty/duplicate PATH entries and Windows PATHEXT | Shell aliases/functions are not visible; platform permission results follow the public access API |
| `date` | subset verified | UTC/TZ, fixed offsets, checked 64-bit TZif/POSIX future rules, ISO local input, fractional epochs, selected ISO/RFC/format directives | Ambiguous/nonexistent local times reject; relative dates/additional directives and clock setting remain; x/time offset bounds are documented |
| `od`, `hexdump` | subset verified | Frozen Linux float formats, od strings/traditional offsets, custom hexdump format/color units, partial elements and final offsets | Non-C/native-ABI equivalence is unclaimed; hexdump forward stdin skip is a documented extension, not util-linux pipe parity |
| `md5sum`, `sha1sum`, `sha512sum` | subset verified | Incremental hashes, tags, GNU escaped/tagged check records and manifest flags | Windows text transformation remains outside the selected C byte profile |
| `sed` | subset verified | BRE/ERE substitution, captures, addresses/ranges and ordered scripts; published 0.2.0 adds hold/branch/group/multiline/text execution and repeated nullable captures | [Workspace candidate scope](#published-matcher-and-sed-profiles) retains project diagnostic formatting and script-controlled space growth; in-place editing and complete GNU grammar remain open |
| `diff` | subset verified | Published 0.2.1 borrows input record views while retaining normal/unified/context output, selected C-byte whitespace/case rules and recursive directory/new-file modes with 0/1/2 statuses | Distinct directory device numbers need public metadata; full GNU grammar and every ambiguous alignment choice remain outside the selected scope |
| `patch` | subset verified | Unified/context offset/fuzz matching, reverse detection, partial success, dry run and new reject files | Existing target/named-output mode preservation and existing-reject replacement retain their public-API boundaries |
| `split`, `csplit` | subset verified | Selected chunk/line-byte/filter layouts and suffix starts/elision; csplit suffix/suppress-matched/keep-files and indexed input snapshots; published R versions 0.1.3 and 0.2.1 | Existing outputs refuse until safe identity/truncation effects are established; filter tasks, created-output paths, regex-line storage and [matcher limits](#published-matcher-and-sed-profiles) remain explicit |
| `expr` | subset verified | Integer/string expressions and BRE matches; published 0.2.0 uses the shared capture matcher | C-byte locale; [matcher limits](#published-matcher-and-sed-profiles) and remaining expression extensions are project work |
| `fmt` | subset verified | Published 0.1.2 adds crown/tagged margins and prefix matching to width/goal/spacing optimization | C-byte locale; paragraph resources and non-C width acceptance remain separate |
| `gzip`, `gunzip`, `zcat` | subset verified | Published 0.1.2: pure 32 KiB LZ, 3–258 byte matches, stored/fixed/dynamic costs, `-1`–`-9` and aliases; Reader decoding with 64 KiB input/output, 32 KiB history and main/secondary tables preserves members, CRC and error prefixes | Historical 0.1.1 keeps its frozen profile. [G1 development evidence](../CHANGELOG.md#2026-10-24) covers GNU roundtrips and selected size limits; 30 codec tests pass Native/Wasm. Formal performance remains open. Bytes callers retain input; levels are ignored during decoding/testing. Named replacement and saved metadata remain boundaries. |
| `base32` | subset verified | RFC 4648 uppercase encode/decode, `-d`, `-i`, `-w`, stdin or one file | Nonstandard alphabets and locale diagnostics not claimed |
| `cksum` | subset verified | POSIX/legacy and selected modern algorithms/lengths, tagged/untagged/base64/raw records and manifest checking | C byte profile; Windows text translation remains outside the selected evidence |
| `expand` | subset verified | C-locale tab expansion, `-i`, `-t` stops, stdin or multiple files | Locale display widths and non-byte tab semantics are not claimed |
| `base64` | subset verified | `-d/-D`, `-i/--ignore-garbage`, `-w N`, file and stdin encode/decode | Nonstandard alphabets and locale diagnostics not claimed |
| `basename` | subset verified | `-a`, `-s SUFFIX`, `-z`, empty/root/repeated-separator operands | Full multibyte path locale behavior not claimed |
| `cat` | subset verified | files/stdin; `-n -b -s -A -E -T -v -e -t`, `-u/--unbuffered` | Unbuffered is a stream-safe compatibility no-op |
| `chmod` | subset verified | Numeric modes, closed symbolic assignments, command-line symlink following, recursive symlink skipping | Incremental/implicit symbolic modes need public mode reads; full recursive command-line directory-symlink combinations remain unverified |
| `cmp` | subset verified | equal=0, different=1, error=2; `-s -l -n -i -b/--print-bytes`, C octal/visible byte notation and EOF distinctions | Non-C locale and every diagnostic form remain outside the selected evidence |
| `comm` | subset verified | Three columns, `-123`, `-z`, last order policy, custom output delimiter, totals including suppressed columns | Locale collation beyond C bytes not claimed |
| `cp` | subset verified | `--no-preserve=mode` to new regular files/trees; no-clobber/update no-ops; traversal controls | Default source-mode preservation and every existing regular-file overwrite reject until public mode/identity/handle-truncate APIs exist; same-inode aliases remain intact |
| `curl` | subset verified | Existing HTTP/HTTPS transfer profile plus Basic `-u`, literal/Netscape `-b`, `-c`, redirect cookie state and credential origin boundaries; 0.2.1 sends separate explicit/jar Cookie fields | Literal cookies remain scoped to the initial origin as in pinned curl 8.22.0. No non-Basic auth/password prompts/PSL/IDNA/raw Set-Cookie input files; 0.2.1 includes the explicit Cookie plus jar correction |
| `cut` | subset verified | Byte/field ranges, complement, custom output delimiter, empty/NUL delimiters, `-s/-z` | Locale/multibyte behavior not claimed |
| `dirname` | subset verified | multiple operands and `-z`, empty/root/repeated-separator operands | Multibyte path locale behavior not claimed |
| `echo` | subset verified | `-n`, `-e`, `-E`, byte escapes, literal `--` ambiguity | `POSIXLY_CORRECT` profile not claimed |
| `env` | subset verified | Complete inherited environment, `-i/-u/-0/-C`, GNU split-string quoting/expansion/splicing and direct children | Windows Native rejects empty final child environments with status 125 until the released async block construction is fixed; empty enumeration, nonempty assignments, POSIX and Wasm remain supported. No host-shell interpretation |
| `false` | subset verified | any args: no output, status 1; help/version return 0 | Metadata text is package-versioned |
| `find` | restricted | names/paths/types, `-empty/-size`, metadata predicates, access checks, `-xtype`, depth/actions | File/process policy required; P8 time/reference/access combinations still need independent probes; ownership, inode, link-count, and full GNU expression grammar not claimed |
| `grep` | subset verified | Default BRE / `-G`, ERE / `-E`, byte-based `-F`, `-o` leftmost-longest, context-only separators, existing context/file/binary options; published 0.3.0 adds the shared matcher, grammar-preserving ASCII `-i`, streaming input/output and early `-q`/`-l` completion | [Workspace matcher limits](#published-matcher-and-sed-profiles), non-C locale classes/case folding and worst-case capture/reference resources remain open |
| `rg` | unpublished candidate | Fixed rg.mbt 0.2.0 algorithms and Unicode data; asynchronous explicit-file/directory/stdin search, glob/ignore, output modes and user preprocessing | [rg candidate](#rg-candidate); effective `-z` rejects; no-path search needs explicit input; public system API and inherited engine limits remain |
| `head` | subset verified | `-n`, `-c`, signed/attached/long/legacy counts and decimal/binary/IEC size suffixes, `-z`, `-q/-v`, files/stdin and headers | Counts are bounded by signed 64-bit storage; locale-aware records are not claimed |
| `join` | subset verified | Field/unpaired/empty output, `-z`, ASCII ignore-case, headers, automatic or accumulated explicit output fields, last order policy | Locale behavior beyond the fixed C profile not claimed |
| `jq` | subset verified | Consecutive JSON, -s/-R/-n/-e, AST binding, partial output before errors, -C/-M/JQ_COLORS, tostring/tojson and Unicode string slices | Released moonjq 0.2.0 plus public-AST adapter; full evaluator/modules/streaming/diagnostics and automatic TTY color are not claimed |
| `jqlog` | subset verified | JSONL stdin/raw input, -f/-h, invalid-line skipping, conversions and Unicode slices | Independent JSONL contract; invalid whitespace lines are not repaired by trimming; full jq CLI compatibility is not claimed |
| `ln` | subset verified | Symbolic -s/-r, last -f/-i selection, -n/-T/-t, backup/suffix/-v and refusal status 1 including EOF | POSIX symlinks; hard-link requests reject before mutation; broader overwrite/target combinations remain |
| `ls` | subset verified | Existing traversal/sort/link profile plus C quoting, columns/across/commas, width/tab stops and explicit type/suffix/link colors | `-P` is a project extension; enabled raw-mode/capability/link-count predicates and automatic color reject. Long/ownership/inode/block formats remain outside scope |
| `make` | subset verified | Real `-j` dependency scheduling, shared prerequisites once, failed-dependency propagation, `-k`, `$(shell ...)`, `.SHELLSTATUS`, cwd and exported recipe variables | No GNU jobserver/full Make grammar claim; shell-function export recursion and full GNU variable semantics remain project work |
| `mkdir` | subset verified | `-p`, numeric and umask-independent symbolic `-m`, requested leaf mode and existing no-ops | Truly umask-dependent results, unknown parent raw mode/owner adjustments and unavailable Windows setters reject |
| `mktemp` | subset verified | Final X-run/default/inferred/explicit suffix rules, tmpdir precedence, quiet errors and exclusive secure-random files/directories | No unsafe `-u`; POSIX mode relationships and Windows supported effects have separate scenarios |
| `mv` | subset verified | Files/dirs, -f/-n/-i, -T/-v, selected backup/suffix/update, same-entry/hard-link no-op failures and refusal status 1 | Equal-time interactive/update targets reject without public identity; no-clobber remains a successful skip; metadata-preserving EXDEV fallback remains unavailable |
| `nl` | subset verified | `-b/-h/-f`, `-w`, `-s`, `-v`, `-i`, `-d`, `-p`, files/stdin | Locale-aware formatting not claimed |
| `paste` | subset verified | parallel/serial `-s`, delimiter cycling `-d`, `-z` | Full malformed delimiter diagnostics not claimed |
| `printenv` | subset verified | selected/all values and `-0`, mixed present/missing status | Wasm environment is policy-dependent |
| `printf` | subset verified | Published 0.2.2 adds exact frozen-ABI hex floats and C-byte GNU `%q` to format reuse, flags and numeric conversions | Fixed Linux amd64 numeric profile; non-C locale and every GNU diagnostic not claimed |
| `pwd` | subset verified | `-L`, `-P`, invalid logical `PWD` fallback | Logical/physical result follows Wasm cwd contract |
| `rm` | subset verified | Files/trees, explicit per-entry/once interaction, last force/interactive policy, iterative prompt order and root-preservation flags | Automatic terminal-dependent write-protection prompts need public terminal/raw-mode metadata; final dot/dot-dot operands reject |
| `realpath` | subset verified | Component-wise default/-e/-m, strip/no-symlinks, relative-to/base, quiet/NUL and ordered operands | Only unresolved physical link targets need readlink; lexical missing paths do not |
| `rev` | subset verified | Published 0.1.4 reverses one ASCII/NUL record at a time into buffered output under the fixed Linux C profile, with invalid-record rejection, prefix retention and later-file continuation | Storage follows the longest record; non-ASCII records fail before output and multibyte locale semantics remain outside the profile |
| `rmdir` | subset verified | empty removal, `-p`, `-I`, `-v`, failure ordering | Full path diagnostics not claimed |
| `seq` | subset verified | Published 0.2.3 adds single-conversion `-f`, frozen-ABI rounding and endpoint recovery; default +/- step, -w/-s and streaming output remain | Default path retains 4096-character/exponent/scale limits; formatted path uses the selected Extended80 range, not the host ABI; formal performance remains open |
| `sh` | subset verified | Persistent `-i` line REPL and opaque Session; export/local variables, cwd, quoting/IFS/glob, arithmetic, substitution, read, bounded printf/test, functions and pipeline state isolation | No public isatty/raw/editing/recoverable SIGINT/job control/exec; remaining interpreter grammar restrictions are project work, listed in command README |
| `sha256sum` | subset verified | File/stdin digest, tags, escaped/tagged manifests and quiet/status/strict/warn/ignore-missing verification | Windows text transformation remains outside the selected C byte profile |
| `sleep` | subset verified | fractional values, `s/m/h/d`, multiple operands, help/version | Signal/cancellation parity not claimed |
| `sort` | subset verified | Published 0.2.3 retains stable/merge/output and exact seeded GNU random order and adds buffer-size, temporary-directory and batch-size controls | Percentage budgets require public physical-memory capacity; existing merge-output identity/error effects reject explicitly, and non-C locale and formal RSS/performance remain open |
| `tail` | subset verified | Existing line/byte/origin/follow profile plus NUL records, final terminators and ordered file headers | `-f` follows open descriptors; stdin/pipes stop at EOF; `-F` path-follow and rotation reopen remain outside scope |
| `tac` | subset verified | Published 0.1.4 uses backward block reads for fixed separators and owned input spools, retaining before/regex/nullable/overlap selection | Regex retains O(input) memory with signed 32-bit matcher indices until a paged/seekable matcher exists; non-C locale remains open |
| `tee` | subset verified | stdin to stdout/files, append, five explicit output-error/pipe policies and observed partial/later-sink effects | Default SIGPIPE termination needs a released restore/raise API and has an exact status-2 rejection scenario |
| `test` | subset verified | string/integer, file kinds, access, regular-file size, `!`, `-a`, `-o`, and the exercised dangling-link path | `-N`/`-nt`/`-ot` and special-file positive fixtures need independent probes; complete unary/binary ambiguity not claimed |
| `tree` | subset verified | C text/JSON/safe HTML, iterative filters/prune/filelimit, explicit colors, actual public sizes and postorder disk-usage reporting | Linux directory size is supported; observed macOS directory size rejects and Windows follows its API result. Selected symlinks/raw-mode colors need readlink/mode; HTML page differences are deliberate |
| `timeout` | local-only | local duration and expiry returned 124 | No published process-group cancellation |
| `touch` | subset verified | Create missing files; `-c` missing-file no-op | Existing-file timestamp updates and setters explicitly fail without content rewrites |
| `tr` | subset verified | translate/delete/squeeze/`-c/-C` complement, `-t`, ranges, C-locale classes, octal/equivalence/repetition forms | Verified profile is byte-oriented; locale data beyond C is not claimed |
| `true` | subset verified | any args: no output, status 0; help/version | Metadata text is package-versioned |
| `uniq` | subset verified | Adjacent filtering, counts, selected repeated/unique members, all-repeated/group separators, `-i/-f/-s/-w/-z` | Fixed C-byte comparisons; non-C collation not claimed |
| `unlink` | subset verified | Exactly one regular-file/symlink operand, -- separator, help/version | Extra operands reject before any deletion; directories reject |
| `unexpand` | subset verified | Leading/all blank conversion, `--first-only`, `-t` stops, stdin or multiple files | Locale display widths and non-byte tab semantics are not claimed |
| `wc` | subset verified | C-byte counters, display width, four total policies, `--files0-from`, partial read-error counts, files/stdin | Non-C counters and regular-stdin physical-fstat alignment are not claimed; see ADR-0003 |
| `wget` | subset verified | Existing transfer profile plus challenge-based Basic credentials across destinations; `--auth-no-challenge` sends explicit credentials on every request, including redirects; load/save cookies, session-cookie option, shared redirect jar; 0.2.1 lets explicit Cookie override stored cookies | No recursive mirror/FTP/HSTS/PSL/IDNA; consumed stdin bodies cannot replay an auth challenge; cross-port and cross-operand authentication caching and full progress text not claimed; explicit Cookie override is delivered in 0.2.1 |
| `yes` | subset verified | Infinite repeated `y` or joined arguments, help/version, broken-pipe termination | Exact signal diagnostics and terminal interaction are not claimed |
| `xargs` | subset verified | Existing batching/process windows plus raw delimiter grammar, last -0/-d selection and separately opened interactive confirmations; empty Windows `-p -r` exits 0 when CONIN$ opens | Child policy remains required; invalid-byte argv needs public byte transport. POSIX no-channel fixtures reject before input/launch; an available unattended Windows console waits for confirmation |
| `xxd` | subset verified | Styles/autoskip/group/case/EBCDIC, wide named-file seeks, forward stdin discard, reverse address adjustment and new named output backpatching | Existing-output identity/mode/content and backward/end-relative stdin seek retain narrow public-API limits |

## Common capability boundaries

Help text and parser acceptance alone do not establish support. Each command
row above states its selected profile and retained limits. Explicit rejections
include incremental/reference chmod modes, cp preservation/overwrite, hard
links, umask-dependent mkdir modes, existing sort merge outputs, timestamp
setters and unseekable backward stdin positions.

The public filesystem profile exposes file kind, supported size metadata,
a/m/c times, access checks and symlink creation. Mode/identity reads, timestamp
setters, hard links, readlink and special-file creation remain unavailable to
these product paths. EXDEV means rename failed; mv has no copy/delete fallback.

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

Build Wasm commands and the Native test driver once, then pass the Wasm build
root to the unified runner. The runner creates isolated directories, captures stdout,
stderr, exit status, and side effects independently, and applies network policy
only in the policy suite. Record positive and negative cases together. Update
this record and the command README only after Wasm semantics, the applicable
pinned oracle cases, and Wasm policy checks are repeatable.

Per-command decisions are in [`docs/adr/README.md`](adr/README.md). Source provenance and fixed
reference versions are in [upstream baselines](upstream-baselines.md); dated
delivery history is in [CHANGELOG.md](../CHANGELOG.md).
