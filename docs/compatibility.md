# Command Support Record

Date: 2026-09-05
Updated: 2026-10-24

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

## Workspace matcher and sed candidates

Core **0.8.0**, grep **0.3.0**, and sed/expr/csplit **0.2.0** are unpublished
workspace candidates. The published coordinates and frozen expectations above
remain unchanged. The [S implementation report](reports/2026-10-24-s-matcher-sed.md)
records local evidence; stage acceptance and
[issue #28](https://github.com/moonbit-community/cmd/issues/28) remain pending
current-revision PR checks and release acceptance.

The shared C-byte matcher parses BRE/ERE once, supports the tested byte classes,
word assertions and pattern backreferences, and exposes span-only search
to grep. Csplit and sed regex addresses use a capture-free predicate; expr and
sed substitutions request capture registers, following GNU's distinct calls.
Grep's ASCII `-i` expands literals/classes before class negation,
preserves assertion escapes and compares references without changing captured
bytes. Tac and nl have not migrated here.
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
do not establish complete GNU/POSIX compatibility; platform/audit, publication
and performance gates remain.

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
| `strings` | subset verified | 7/8-bit extraction, TAB, decimal/octal/hex offsets, -o/-t precedence, filenames and stdin markers | Wide/object/Unicode/locale modes remain; unsupported encodings reject before processing |
| `column` | subset verified | Default grid/-x, -c/COLUMNS, -t/-s/-o, empty fields, multiple files, final LF and table ANSI widths | C-byte display profile; full util-linux grammar and automatic terminal width remain |
| `which` | subset verified | Direct/PATH executable access, -a/-s, POSIX separators, empty/duplicate PATH entries and Windows PATHEXT | Shell aliases/functions are not visible; platform permission results follow the public access API |
| `date` | subset verified | UTC/TZ, fixed offsets, checked 64-bit TZif/POSIX future rules, ISO local input, fractional epochs, selected ISO/RFC/format directives | Ambiguous/nonexistent local times reject; relative dates/additional directives and clock setting remain; x/time offset bounds are documented |
| `od`, `hexdump` | subset verified | Integer and character formats, offsets, lengths, duplicate blocks, raw byte input | Floating od types and custom hexdump format language are project work; default integers use little endian |
| `md5sum`, `sha1sum`, `sha512sum` | subset verified | Incremental hashes, file/stdin, GNU check records and check flags | Tagged formats and platform text transformations are not claimed |
| `sed` | subset verified | BRE/ERE substitution, captures, addresses/ranges and ordered scripts; unpublished 0.2.0 adds hold/branch/group/multiline/text execution and repeated nullable captures | [Workspace candidate scope](#workspace-matcher-and-sed-candidates) retains project diagnostic formatting and script-controlled space growth; current-revision acceptance, in-place editing and complete GNU grammar remain open |
| `diff` | subset verified | Normal/unified/context text output, labels, binary detection and 0/1/2 statuses | Directory and whitespace modes remain project work; exact hunk choices for ambiguous alignments need separate comparison |
| `patch` | subset verified | Exact unified/context hunks, reverse, stdout result, dry run, creation/deletion | Existing destination and named output require public source mode; fuzzy/offset/reject-file behavior is not claimed |
| `split`, `csplit` | subset verified | Line/byte splitting, numeric/regex boundaries, suffixes, cleanup and keep-files; unpublished csplit 0.2.0 uses the shared span matcher | Existing output refuses until safe truncation is public; chunk/filter modes and the [shared matcher limits](#workspace-matcher-and-sed-candidates) remain open |
| `expr`, `fmt` | subset verified | Integer/string expressions and BRE matches; paragraph width/goal/spacing; unpublished expr 0.2.0 uses the shared capture matcher | C-byte locale; [matcher limits](#workspace-matcher-and-sed-candidates) and remaining expression/formatting extensions are project work |
| `gzip`, `gunzip`, `zcat` | subset verified | Unpublished 0.1.2: pure 32 KiB LZ, 3–258 byte matches, stored/fixed/dynamic costs, `-1`–`-9` and aliases; Reader decoding with 64 KiB input/output, 32 KiB history and main/secondary tables preserves members, CRC and error prefixes | Published 0.1.1 keeps its frozen profile. [G1 development evidence](reports/2026-10-24-g1-codec.md) covers GNU roundtrips and selected size limits; 30 codec tests pass Native/Wasm. Published delivery/performance remain open. Bytes callers retain input; levels are ignored during decoding/testing. Named replacement and saved metadata remain boundaries. |
| `base32` | subset verified | RFC 4648 uppercase encode/decode, `-d`, `-i`, `-w`, stdin or one file | Nonstandard alphabets and locale diagnostics not claimed |
| `cksum` | subset verified | POSIX CRC-32 and byte count for stdin or multiple files, ordered partial failure | GNU alternate algorithms and tagged output are not claimed |
| `expand` | subset verified | C-locale tab expansion, `-i`, `-t` stops, stdin or multiple files | Locale display widths and non-byte tab semantics are not claimed |
| `base64` | subset verified | `-d/-D`, `-i/--ignore-garbage`, `-w N`, file and stdin encode/decode | Nonstandard alphabets and locale diagnostics not claimed |
| `basename` | subset verified | `-a`, `-s SUFFIX`, `-z`, empty/root/repeated-separator operands | Full multibyte path locale behavior not claimed |
| `cat` | subset verified | files/stdin; `-n -b -s -A -E -T -v -e -t`, `-u/--unbuffered` | Unbuffered is a stream-safe compatibility no-op |
| `chmod` | subset verified | Numeric modes, closed symbolic assignments, command-line symlink following, recursive symlink skipping | Incremental/implicit symbolic modes need public mode reads; full recursive command-line directory-symlink combinations remain unverified |
| `cmp` | subset verified | equal=0, different=1, error=2; `-s -l -n -i` | Full diagnostic byte parity not claimed |
| `comm` | subset verified | three columns, `-1 -2 -3`, `-z`, `--check-order`, `--nocheck-order`, `-`, clustered flags | Locale collation beyond C bytes not claimed |
| `cp` | subset verified | `--no-preserve=mode` to new regular files/trees; no-clobber/update no-ops; traversal controls | Default source-mode preservation and every existing regular-file overwrite reject until public mode/identity/handle-truncate APIs exist; same-inode aliases remain intact |
| `curl` | subset verified | Existing HTTP/HTTPS transfer profile plus Basic `-u`, literal/Netscape `-b`, `-c`, redirect cookie state and credential origin boundaries; 0.2.1 sends separate explicit/jar Cookie fields | Literal cookies remain scoped to the initial origin as in pinned curl 8.22.0. No non-Basic auth/password prompts/PSL/IDNA/raw Set-Cookie input files; 0.2.1 includes the explicit Cookie plus jar correction |
| `cut` | subset verified | `-c`, `-f`, `-d`, `-s`, `-z`, range/comma lists | Locale/multibyte behavior not claimed |
| `dirname` | subset verified | multiple operands and `-z`, empty/root/repeated-separator operands | Multibyte path locale behavior not claimed |
| `echo` | subset verified | `-n`, `-e`, `-E`, byte escapes, literal `--` ambiguity | `POSIXLY_CORRECT` profile not claimed |
| `env` | subset verified | Complete inherited environment, `-i/-u/-0/-C`, direct children, `--help/--version` | Host authorization is separate; child launch error classes remain explicit |
| `false` | subset verified | any args: no output, status 1; help/version return 0 | Metadata text is package-versioned |
| `find` | restricted | names/paths/types, `-empty/-size`, metadata predicates, access checks, `-xtype`, depth/actions | File/process policy required; P8 time/reference/access combinations still need independent probes; ownership, inode, link-count, and full GNU expression grammar not claimed |
| `grep` | subset verified | Default BRE / `-G`, ERE / `-E`, byte-based `-F`, `-o` leftmost-longest, context-only separators, existing context/file/binary options; unpublished 0.3.0 adds the shared matcher, grammar-preserving ASCII `-i`, streaming input/output and early `-q`/`-l` completion | [Workspace matcher limits](#workspace-matcher-and-sed-candidates), non-C locale classes/case folding and worst-case capture/reference resources remain open |
| `head` | subset verified | `-n`, `-c`, signed/attached/long/legacy counts and decimal/binary/IEC size suffixes, `-z`, `-q/-v`, files/stdin and headers | Counts are bounded by signed 64-bit storage; locale-aware records are not claimed |
| `join` | subset verified | `-1 -2 -t -a -v -e -o`, `-z`, `-` stdin | Locale diagnostics not claimed |
| `jq` | subset verified | Consecutive JSON, -s/-R/-n/-e, AST binding, partial output before errors, -C/-M/JQ_COLORS, tostring/tojson and Unicode string slices | Released moonjq 0.2.0 plus public-AST adapter; full evaluator/modules/streaming/diagnostics and automatic TTY color are not claimed |
| `jqlog` | subset verified | JSONL stdin/raw input, -f/-h, invalid-line skipping, conversions and Unicode slices | Independent JSONL contract; invalid whitespace lines are not repaired by trimming; full jq CLI compatibility is not claimed |
| `ln` | subset verified | Symbolic -s/-r, last -f/-i selection, -n/-T/-t, backup/suffix/-v and refusal status 1 including EOF | POSIX symlinks; hard-link requests reject before mutation; broader overwrite/target combinations remain |
| `ls` | subset verified | `-a -A -d -F -1 -R`, reverse, regular-file `-S`, `-H/-L` link following, implicit `-u/-c` time sorting and `-S/-t` precedence | Native/Wasm command contracts and pinned GNU 9.11 Linux gate passed. `-P` is a project extension (GNU rejects it); directory-size sorting, long/colour/ownership/inode/block formats not claimed |
| `make` | subset verified | Real `-j` dependency scheduling, shared prerequisites once, failed-dependency propagation, `-k`, `$(shell ...)`, `.SHELLSTATUS`, cwd and exported recipe variables | No GNU jobserver/full Make grammar claim; shell-function export recursion and full GNU variable semantics remain project work |
| `mkdir` | subset verified | `-p`, numeric `-m`, requested mode on leaf only; default parent mode under ordinary umask | Symbolic modes and unusual umasks requiring temporary owner permissions remain unverified |
| `mktemp` | subset verified | One template, secure random suffix, `-d/--directory`, atomic create, 0600 files and 0700 directories | Template extensions, owner metadata and platform-specific permission details are not claimed |
| `mv` | subset verified | Files/dirs, -f/-n/-i, -T/-v, selected backup/suffix/update, same-entry/hard-link no-op failures and refusal status 1 | Equal-time interactive/update targets reject without public identity; no-clobber remains a successful skip; metadata-preserving EXDEV fallback remains unavailable |
| `nl` | subset verified | `-b/-h/-f`, `-w`, `-s`, `-v`, `-i`, `-d`, `-p`, files/stdin | Locale-aware formatting not claimed |
| `paste` | subset verified | parallel/serial `-s`, delimiter cycling `-d`, `-z` | Full malformed delimiter diagnostics not claimed |
| `printenv` | subset verified | selected/all values and `-0`, mixed present/missing status | Wasm environment is policy-dependent |
| `printf` | subset verified | reused formats, conversions, width/precision, flags, escapes, numeric repetition, `--` | Locale and every GNU diagnostic not claimed |
| `pwd` | subset verified | `-L`, `-P`, invalid logical `PWD` fallback | Logical/physical result follows Wasm cwd contract |
| `rm` | subset verified | files/trees, `-r/-f/-d/-v`, failure ordering, root-preservation flags | Final dot/dot-dot operands are rejected, including Windows separators; explicit cwd paths do not receive additional policy |
| `realpath` | subset verified | Existing path canonicalization, `-e`, `-z`, multiple operands | GNU missing-path `-m` semantics and every diagnostic byte are not claimed |
| `rev` | subset verified | C-locale byte reversal per line, stdin or one file, line-feed preservation | Multibyte locale character semantics and multiple files are not claimed |
| `rmdir` | subset verified | empty removal, `-p`, `-I`, `-v`, failure ordering | Full path diagnostics not claimed |
| `seq` | subset verified | One/two/three operands, default +1, negative step, -w/-s, version and streaming output without a record-count cap | Operands limited to 4096 characters and exponent/scale to 4096; -f remains unavailable; 10,000,001 records verified |
| `sh` | subset verified | Persistent `-i` line REPL and opaque Session; export/local variables, cwd, quoting/IFS/glob, arithmetic, substitution, read, bounded printf/test, functions and pipeline state isolation | No public isatty/raw/editing/recoverable SIGINT/job control/exec; remaining interpreter grammar restrictions are project work, listed in command README |
| `sha256sum` | subset verified | file/stdin digest, `-c`, `-z`, quiet/status/strict/warn/ignore-missing verification modes | Binary manifest extensions and every warning byte not claimed |
| `sleep` | subset verified | fractional values, `s/m/h/d`, multiple operands, help/version | Signal/cancellation parity not claimed |
| `sort` | subset verified | repeated `-k` field/character modifiers with GNU blank boundaries; `-b -d -f -i -n -g -h -M -V -r -u -z`; `-c/-C` checks | `-R` is a verified rejection without a seed contract; locale/external-sort semantics not claimed |
| `tail` | subset verified | `-n`, `-c`, `+K`, `-q`, `-v`, `-f`/`--follow`, `-s`/`--sleep-interval` | `-f` follows open regular-file descriptors by polling; stdin/pipes stop at EOF; `-F` path-follow and rotation reopen are not claimed |
| `tac` | subset verified | Reverse records from stdin or one file, `-s/--separator`, `-b/--before` | Regex separators and multiple input files are rejected; locale diagnostics not claimed |
| `tee` | subset verified | stdin to stdout/files and `-a` append, partial-output ordering | Signal diagnostics not claimed |
| `test` | subset verified | string/integer, file kinds, access, regular-file size, `!`, `-a`, `-o`, and the exercised dangling-link path | `-N`/`-nt`/`-ot` and special-file positive fixtures need independent probes; complete unary/binary ambiguity not claimed |
| `tree` | subset verified | Sorted recursive display, `-a -d -f -L --noreport`, multiple roots | Symlink targets and metadata need readlink/mode/identity APIs; color, filters and extended output formats are separate project work |
| `timeout` | local-only | local duration and expiry returned 124 | No published process-group cancellation |
| `touch` | subset verified | Create missing files; `-c` missing-file no-op | Existing-file timestamp updates and setters explicitly fail without content rewrites |
| `tr` | subset verified | translate/delete/squeeze/`-c/-C` complement, `-t`, ranges, C-locale classes, octal/equivalence/repetition forms | Verified profile is byte-oriented; locale data beyond C is not claimed |
| `true` | subset verified | any args: no output, status 0; help/version | Metadata text is package-versioned |
| `uniq` | subset verified | adjacent filtering, `-c -d -u -i`, `-f -s -w -z`, exact count spacing | Fixed C-locale field/character comparison; locale collation not claimed |
| `unlink` | subset verified | Exactly one regular-file/symlink operand, -- separator, help/version | Extra operands reject before any deletion; directories reject |
| `unexpand` | subset verified | Leading/all blank conversion, `--first-only`, `-t` stops, stdin or multiple files | Locale display widths and non-byte tab semantics are not claimed |
| `wc` | subset verified | `-l -w -c -m -L`, combinations, aligned multi-file totals, `--files0-from`, files/stdin | `-L` is the C-locale display-width profile; full locale diagnostics not claimed |
| `wget` | subset verified | Existing transfer profile plus challenge-based Basic credentials across destinations; `--auth-no-challenge` sends explicit credentials on every request, including redirects; load/save cookies, session-cookie option, shared redirect jar; 0.2.1 lets explicit Cookie override stored cookies | No recursive mirror/FTP/HSTS/PSL/IDNA; consumed stdin bodies cannot replay an auth challenge; cross-port and cross-operand authentication caching and full progress text not claimed; explicit Cookie override is delivered in 0.2.1 |
| `yes` | subset verified | Infinite repeated `y` or joined arguments, help/version, broken-pipe termination | Exact signal diagnostics and terminal interaction are not claimed |
| `xargs` | restricted | whitespace/NUL tokenization, quotes/backslashes, `-0 -r -t -n -L -s -E -I`, `--show-limits`, bounded `-P`; direct-child status classes 123/124/125/126/127 | Child policy required; process windows are bounded and aggregate status deterministically; GNU shell/locale extensions are not claimed |
| `xxd` | subset verified | forward hex, `-p -r -c -l -i`, `--revert`, include symbol naming, positive `-s`, addressed reverse patching with bounded offsets | Negative/end-relative seek remains rejected; loose reverse-offset parsing matches the pinned profile and oversized offsets are rejected before unbounded allocation |

## Help-Visible Only

The following options appeared in the current Wasm `--help` output but are not
called “supported” above because this audit did not exercise a complete
positive result. They are probe targets, not product claims.

| Command | Help-visible only |
| --- | --- |

Each row identifies the option families exercised successfully. Explicit
rejections, including `chmod` incremental/reference modes,
`cp -a/-p`, `ln` hard links, `mkdir` symbolic modes, `sort -R`, timestamp
selectors for `touch`, and negative `xxd -s`, are recorded in their rows. The
portable filesystem profile exposes file kind, regular-file size, a/m/c times,
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
