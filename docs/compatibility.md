# Command Support Record

Date: 2026-09-05
Updated: 2026-09-26

**0.2.0 is published** for `cli/core` and 47 command modules. The
[source gate](https://github.com/moonbit-community/cmd/actions/runs/35576541301)
passed on Linux, macOS and Windows, including Linux Native/Wasm comparisons
with the pinned oracle. These source checks remain distinct from exact-version
MoonX acceptance, recorded in the
[release evidence](reports/2026-09-21-release-0.2.0/README.md). The historical
0.1.x manifests remain unchanged for replay. See
[public API gaps](async-upstream-gaps.md).

The current unpublished workspace uses async 0.22.4 and adds the documented
local-only command profiles for base32, mktemp, realpath, rev, tac, tree,
unlink and yes. It also corrects custom Cookie plus jar handling:
curl sends two separate fields; wget sends the explicit field instead of the
stored-cookie field. It also adopts MoonBit 2026-09-20 with strict warning
cleanup. These changes are not included in the 0.2.0 registry packages.

Authorization belongs to the caller/host. Catalog capabilities and the older
restricted label describe requirements, not command-local policy.

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
builds a command package during a case. The selected versions and case IDs are
recorded in `tests/release_runner/published-0.2.0.json`; `latest`, version ranges and
implicit package resolution are forbidden.

The release manifest must cover every published command (47 commands; the
`timeout` package remains local-only), and every option/operand form promoted in
this record must have positive, boundary, failure and side-effect cases. Help
and version text use contract comparison where project branding differs from
GNU; bytes, status, final newlines and version tokens remain checked. Policy
authorization is separate and continues to run through `moonrun --policy` in
the unified runner.

For every release, update the package version, command README, release
manifest and case coverage together. After the Wasm asset is available, run:

The published manifest selects 382 active cases. `candidate-0.2.0.json` remains
a validation-only preparation record; its candidate flags do not describe the
current release status. The consumer driver inserts `--` after the exact MoonX
coordinate so the command's own leading `--` is preserved. The frozen schema 1
`manifest.json` and `published-0.1-base.json` retain the historical release.

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target native tests/release_runner -- \
  --manifest tests/release_runner/published-0.2.0.json --suite validate
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target native tests/release_runner -- \
  --manifest tests/release_runner/published-0.2.0.json --suite differential \
  --oracle-image mooncmd-oracle:phase0
```

Asset/registry transport errors, candidate failures, oracle failures,
semantic mismatches, side-effect violations, timeouts and runner failures are
reported separately. Asset or infrastructure failures are hard failures, not
skips. macOS and Windows use the same exact-version published smoke suite;
only the pinned Linux oracle result promotes a strict differential claim.
HTTP cases use a shared pure-MoonBit loopback fixture; HTTPS fixture cases stay
outside the published selection until their TLS fixture is pinned.
The Windows smoke profile explicitly records POSIX-only permission and symbolic
link cases as `skipped_platform`; Linux/macOS run those cases, and the pinned
Linux oracle remains the strict filesystem authority.

## Inventory

The workspace contains 59 command modules. Mooncakes currently exposes 47
through MoonX; `base32`, `cksum`, `expand`, `mktemp`, `realpath`, `rev`, `tac`, `tree`, `unexpand`, `unlink`,
`yes` and `timeout`
are currently local-only.
`timeout` is intentionally local-only because portable
`ProcessGroupCancellation` is unavailable:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target wasm --release commands/timeout -- 1s printf ok
```

is a valid local invocation, while `moonx cli/timeout` is not a supported
registry invocation. The same local-only status currently applies to
`base32`, `cksum`, `expand`, `mktemp`, `realpath`, `rev`, `tac`, `tree`, `unexpand`, `unlink` and `yes`; their
registry publication is a later release gate. Earlier package versions and their
measured results remain in the frozen manifests and historical reports.

Status vocabulary: `subset verified` is a successful normal-path probe;
`restricted` additionally needs explicit Wasm file/process/network/permission
policy; `verified rejection` is a boundary exercised and rejected before
claiming success; `local-only` is absent from MoonX by design.

## Per-command support

| Command | Status | Measured profile | Observed boundary or open evidence |
| --- | --- | --- | --- |
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
| `curl` | subset verified | Existing HTTP/HTTPS transfer profile plus Basic `-u`, literal/Netscape `-b`, `-c`, redirect cookie state and credential origin boundaries; workspace adds separate explicit/jar Cookie fields | Literal cookies remain scoped to the initial origin as in pinned curl 8.22.0. No non-Basic auth/password prompts/PSL/IDNA/raw Set-Cookie input files; published 0.2.0 still rejects custom Cookie plus stored cookies |
| `cut` | subset verified | `-c`, `-f`, `-d`, `-s`, `-z`, range/comma lists | Locale/multibyte behavior not claimed |
| `dirname` | subset verified | multiple operands and `-z`, empty/root/repeated-separator operands | Multibyte path locale behavior not claimed |
| `echo` | subset verified | `-n`, `-e`, `-E`, byte escapes, literal `--` ambiguity | `POSIXLY_CORRECT` profile not claimed |
| `env` | subset verified | Complete inherited environment, `-i/-u/-0/-C`, direct children, `--help/--version` | Host authorization is separate; child launch error classes remain explicit |
| `false` | subset verified | any args: no output, status 1; help/version return 0 | Metadata text is package-versioned |
| `find` | restricted | names/paths/types, `-empty/-size`, metadata predicates, access checks, `-xtype`, depth/actions | File/process policy required; P8 time/reference/access combinations still need independent probes; ownership, inode, link-count, and full GNU expression grammar not claimed |
| `grep` | subset verified | Default BRE / `-G`, ERE / `-E`, `-F`, `-o` leftmost-longest, context-only separators, existing context/file/binary options | Backreferences and unsupported regex extensions reject; full locale classes and worst-case long-line performance remain project regex work |
| `head` | subset verified | `-n`, `-c`, signed/attached/long/legacy counts and decimal/binary/IEC size suffixes, `-z`, `-q/-v`, files/stdin and headers | Counts are bounded by signed 64-bit storage; locale-aware records are not claimed |
| `join` | subset verified | `-1 -2 -t -a -v -e -o`, `-z`, `-` stdin | Locale diagnostics not claimed |
| `jq` | subset verified | Consecutive JSON values, `-s/-R/-n/-e`, public AST variable binding, partial output on later parse error, explicit `-C` ANSI / `-M` precedence and `JQ_COLORS` | jq 1.8.2 color contracts and Linux pinned comparisons passed on both backends; evaluator remains moonjq 0.1.2; automatic TTY coloring, full modules/streaming/diagnostics not claimed |
| `jqlog` | subset verified | JSONL stdin/raw input, `-f`, `-h`; invalid lines skipped | Compared with imported jqlog contract, not a system utility |
| `ln` | subset verified | symbolic `-s`, exercised `-r`, and the parser's `-f/-i`, `-n/-T`, `-t`, backup/suffix, `-v` paths | Target-directory and overwrite combinations remain certification boundaries; hard-link request rejected before mutation |
| `ls` | subset verified | `-a -A -d -F -1 -R`, reverse, regular-file `-S`, `-H/-L` link following, implicit `-u/-c` time sorting and `-S/-t` precedence | Native/Wasm command contracts and pinned GNU 9.11 Linux gate passed. `-P` is a project extension (GNU rejects it); directory-size sorting, long/colour/ownership/inode/block formats not claimed |
| `make` | subset verified | Real `-j` dependency scheduling, shared prerequisites once, failed-dependency propagation, `-k`, `$(shell ...)`, `.SHELLSTATUS`, cwd and exported recipe variables | No GNU jobserver/full Make grammar claim; shell-function export recursion and full GNU variable semantics remain project work |
| `mkdir` | subset verified | `-p`, numeric `-m`, requested mode on leaf only; default parent mode under ordinary umask | Symbolic modes and unusual umasks requiring temporary owner permissions remain unverified |
| `mktemp` | subset verified | One template, secure random suffix, `-d/--directory`, atomic create, 0600 files and 0700 directories | Template extensions, owner metadata and platform-specific permission details are not claimed |
| `mv` | subset verified | files/dirs, `-f/-n`, `-T`, `-v`, and the exercised `update=none` path | P8 interactive/backup/suffix and remaining update modes need probes; cross-filesystem fallback not claimed; source preserved on rename failure |
| `nl` | subset verified | `-b/-h/-f`, `-w`, `-s`, `-v`, `-i`, `-d`, `-p`, files/stdin | Locale-aware formatting not claimed |
| `paste` | subset verified | parallel/serial `-s`, delimiter cycling `-d`, `-z` | Full malformed delimiter diagnostics not claimed |
| `printenv` | subset verified | selected/all values and `-0`, mixed present/missing status | Wasm environment is policy-dependent |
| `printf` | subset verified | reused formats, conversions, width/precision, flags, escapes, numeric repetition, `--` | Locale and every GNU diagnostic not claimed |
| `pwd` | subset verified | `-L`, `-P`, invalid logical `PWD` fallback | Logical/physical result follows Wasm cwd contract |
| `rm` | subset verified | files/trees, `-r/-f/-d/-v`, failure ordering, root-preservation flags | Final dot/dot-dot operands are rejected, including Windows separators; explicit cwd paths do not receive additional policy |
| `realpath` | subset verified | Existing path canonicalization, `-e`, `-z`, multiple operands | GNU missing-path `-m` semantics and every diagnostic byte are not claimed |
| `rev` | subset verified | C-locale byte reversal per line, stdin or one file, line-feed preservation | Multibyte locale character semantics and multiple files are not claimed |
| `rmdir` | subset verified | empty removal, `-p`, `-I`, `-v`, failure ordering | Full path diagnostics not claimed |
| `seq` | subset verified | One/two/three-number forms, default step +1, explicit negative step, `-w/-s/--version` | `seq 3 1` now produces no output, matching GNU; old descending extension removed |
| `sh` | subset verified | Persistent `-i` line REPL and opaque Session; export/local variables, cwd, quoting/IFS/glob, arithmetic, substitution, read, bounded printf/test, functions and pipeline state isolation | No public isatty/raw/editing/recoverable SIGINT/job control/exec; remaining interpreter grammar restrictions are project work, listed in command README |
| `sha256sum` | subset verified | file/stdin digest, `-c`, `-z`, quiet/status/strict/warn/ignore-missing verification modes | Binary manifest extensions and every warning byte not claimed |
| `sleep` | subset verified | fractional values, `s/m/h/d`, multiple operands, help/version | Signal/cancellation parity not claimed |
| `sort` | subset verified | repeated `-k` field/character modifiers with GNU blank boundaries; `-b -d -f -i -n -g -h -M -V -r -u -z`; `-c/-C` checks | `-R` is a verified rejection without a seed contract; locale/external-sort semantics not claimed |
| `tail` | subset verified | `-n`, `-c`, `+K`, `-q`, `-v`, `-f`/`--follow`, `-s`/`--sleep-interval` | `-f` follows open regular-file descriptors by polling; stdin/pipes stop at EOF; `-F` path-follow and rotation reopen are not claimed |
| `tac` | subset verified | Reverse records from stdin or one file, `-s/--separator`, `-b/--before` | Regex separators and multiple input files are rejected; locale diagnostics not claimed |
| `tee` | subset verified | stdin to stdout/files and `-a` append, partial-output ordering | Signal diagnostics not claimed |
| `test` | subset verified | string/integer, file kinds, access, regular-file size, `!`, `-a`, `-o`, and the exercised dangling-link path | `-N`/`-nt`/`-ot` and special-file positive fixtures need independent probes; complete unary/binary ambiguity not claimed |
| `tree` | subset verified | Sorted recursive display, `-a -d -f -L --noreport`, multiple roots | Symlink targets, color, permissions, device metadata and extended reports are rejected or not claimed because public async fs lacks readlink and mode APIs |
| `timeout` | local-only | local duration and expiry returned 124 | No published process-group cancellation |
| `touch` | subset verified | Create missing files; `-c` missing-file no-op | Existing-file timestamp updates and setters explicitly fail without content rewrites |
| `tr` | subset verified | translate/delete/squeeze/`-c/-C` complement, `-t`, ranges, C-locale classes, octal/equivalence/repetition forms | Verified profile is byte-oriented; locale data beyond C is not claimed |
| `true` | subset verified | any args: no output, status 0; help/version | Metadata text is package-versioned |
| `uniq` | subset verified | adjacent filtering, `-c -d -u -i`, `-f -s -w -z`, exact count spacing | Fixed C-locale field/character comparison; locale collation not claimed |
| `unlink` | subset verified | Multiple regular-file or symlink operands, ordered partial failure, `--help`/`--version` | Directories are rejected; owner metadata and every diagnostic byte are not claimed |
| `unexpand` | subset verified | Leading/all blank conversion, `--first-only`, `-t` stops, stdin or multiple files | Locale display widths and non-byte tab semantics are not claimed |
| `wc` | subset verified | `-l -w -c -m -L`, combinations, aligned multi-file totals, `--files0-from`, files/stdin | `-L` is the C-locale display-width profile; full locale diagnostics not claimed |
| `wget` | subset verified | Existing transfer profile plus challenge-based Basic credentials across destinations; `--auth-no-challenge` sends explicit credentials on every request, including redirects; load/save cookies, session-cookie option, shared redirect jar; workspace lets explicit Cookie override stored cookies | No recursive mirror/FTP/HSTS/PSL/IDNA; consumed stdin bodies cannot replay an auth challenge; cross-port and cross-operand authentication caching and full progress text not claimed; explicit Cookie override is not in published 0.2.0 |
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
