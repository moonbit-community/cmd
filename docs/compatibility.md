# Command Support Record

Date: 2026-09-04

This is the single support record for the `cmd` repository. It replaces the
former matrix and phase-plan documents. Claims are promoted through the unified
runner: native black-box semantic tests, pinned-upstream differential cases,
and separate Wasm authorization tests for restricted commands. The relevant
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

The ordered implementation roadmap is in
[`compatibility-expansion-plan.md`](compatibility-expansion-plan.md). It is a
plan, not an additional support claim.

## Inventory

The local release contains 48 command modules. Mooncakes currently exposes 47
through MoonX. `timeout` is intentionally local-only because portable
`ProcessGroupCancellation` is unavailable:

```text
moon run --target wasm --release commands/timeout -- 1s printf ok
```

is a valid local invocation, while `moonx cli/timeout` is not a supported
registry invocation. The other rows are intended for
`moonx cli/<command>@0.1.2` after their Wasm asset is available.

Status vocabulary: `subset verified` is a successful normal-path probe;
`restricted` additionally needs explicit Wasm file/process/network/permission
policy; `verified rejection` is a boundary exercised and rejected before
claiming success; `local-only` is absent from MoonX by design.

## Per-command support

| Command | Status | Wasm-observed support | Observed boundary or gap |
| --- | --- | --- | --- |
| `base64` | subset verified | `-d`, `-w N`, file and stdin encode/decode | Invalid-input and every GNU alias not probed |
| `basename` | subset verified | `-a`, `-s SUFFIX`, `-z`, multiple names | Full operand ambiguity not probed |
| `cat` | subset verified | files/stdin; `-n -b -s -A -E -T -v -e -t` | Less common GNU flags not claimed |
| `chmod` | restricted | numeric mode, `-R`, `-v`; real mode mutation | `u+x` returned 2; symbolic/reference modes unavailable |
| `cmp` | subset verified | equal=0, different=1; `-s -l -n -i` accepted | Full diagnostic parity not claimed |
| `comm` | subset verified | three columns, `-1 -2 -3`, `-`, clustered flags | Locale/unsorted diagnostics not probed |
| `cp` | subset verified | files, `-R`, `-f/-n`, `-T`, `-v`; tree side effects | `-p/-a` rejected before output; metadata preservation absent |
| `curl` | restricted | Bounded HTTP/HTTPS profile: `-sS -f -o -OJ -L -I -H -X -d -T`; all documented methods; raw/binary/URL-encoded data; filename collisions and cleanup; retries; connect/total/idle timeouts; redirect limits and cross-origin stripping; HTTP CONNECT proxy/bypass; insecure TLS | Non-HTTP protocols, auth/cookie/config state, HTTP/2 negotiation, and exact native progress/diagnostic bytes not claimed |
| `cut` | subset verified | `-c`, `-f`, `-d`, `-s`, range/comma lists | Locale/multibyte/error parity not probed |
| `dirname` | subset verified | multiple operands and `-z` | Remaining path corner cases not probed |
| `echo` | subset verified | `-n`, `-e`, `-E`, escapes | Shell mode ambiguities not probed |
| `env` | restricted | `-i/--ignore-environment`, `-u/--unset`, `-0`, GNU-style non-empty assignment names and option boundary, `-C/--chdir`, direct child launch, statuses 125/126/127 | `--help` is a verified status-125 rejection; cwd and child each require policy |
| `false` | subset verified | any args: no output, status 1 | No help path in artifact |
| `find` | restricted | `-name -path -type -empty -size -mtime -newer -mindepth -maxdepth -depth -prune -print -print0`, one-child and deterministic batched `-exec`, postorder `-delete` | File/process policy required; ownership/link-target predicates and full GNU expression grammar not claimed |
| `grep` | subset verified | existing match modes plus `-A -B -C -b -s -z`, binary policies, recursive `--include/--exclude`, C-locale byte offsets | Include/exclude globs are the portable `*`/`?` basename profile; locale-aware classes and full diagnostics not claimed |
| `head` | subset verified | `-n`, `-c`, signed/attached/long/legacy counts and decimal/binary/IEC size suffixes, `-z`, `-q/-v`, files/stdin and headers | Counts are bounded by signed 64-bit storage; locale-aware records are not claimed |
| `join` | subset verified | `-1 -2 -t -a -v -e -o`, `-` stdin | Legacy aliases/locale diagnostics not probed |
| `jq` | subset verified | `-c -r -f -n -l`; field, compact, null, filter paths | Not a complete jq 1.8 filter-language claim |
| `jqlog` | subset verified | JSONL stdin/raw input, `-f`, `-h`; invalid lines skipped | Compared with imported jqlog contract, not a system utility |
| `ln` | subset verified | symbolic `-s`, `-f`, `-T`, `-v` | Hard-link request rejected before mutation |
| `ls` | subset verified | `-a -A -d -F -1 -R` | Long/colour/ownership/time formats not claimed |
| `make` | restricted | `-B -n -s -C -f`, command-line variables, includes and recipes | Recipe process lookup/cwd follows the Wasm host contract; full GNU language not verified |
| `mkdir` | subset verified | `-p`, numeric `-m`, `-v` | Symbolic mode/umask parity not probed |
| `mv` | subset verified | files/dirs, `-f/-n`, `-T`, `-v` | Cross-filesystem fallback not claimed |
| `nl` | subset verified | `-b`, `-w`, `-s`, files/stdin | Page/section delimiters not probed |
| `paste` | subset verified | parallel/serial `-s`, delimiter cycling `-d` | Full delimiter/error matrix not claimed |
| `printenv` | subset verified | selected/all values and `-0` | Wasm environment is policy-dependent |
| `printf` | subset verified | reused formats, conversions, width/precision, flags, escapes, `--` | Locale and every GNU diagnostic not claimed |
| `pwd` | subset verified | `-L`, `-P`; both status 0 | Logical/physical result follows Wasm cwd contract |
| `rm` | subset verified | files/trees, `-r`, `-f`, `-d`, `-v` | Root/current-directory protection is unconditional |
| `rmdir` | subset verified | empty removal, `-p`, `-I`, `-v` | Full path diagnostics not claimed |
| `seq` | subset verified | one/two/three-number forms, `-w`, `-s` | Full GNU formatting/overflow not probed |
| `sh` | restricted | `-c`, `-s`, script/stdin selection, variables, positional parameters, pipelines and redirections | Child programs require policy; command substitution returned 2, and conditionals depend on child lookup |
| `sha256sum` | subset verified | file/stdin digest, `-c`, `-z` | All checksum warning/status combinations not claimed |
| `sleep` | subset verified | fractional values, `s/m/h/d`, multiple operands | Signal/cancellation parity not claimed |
| `sort` | subset verified | repeated `-k` field/character modifiers with GNU blank boundaries; `-b -d -f -i -n -g -h -M -V -r -u -z`; `-c/-C` checks | `-R` is a verified rejection without a seed contract; locale/external-sort semantics not claimed |
| `tail` | subset verified | `-n`, `-c`, `+K`, `-q`, `-v`, `-f`/`--follow`, `-s`/`--sleep-interval` | `-f` follows open regular-file descriptors by polling; stdin/pipes stop at EOF; `-F` path-follow and rotation reopen are not claimed |
| `tee` | subset verified | stdin to stdout/files and `-a` append | Signal/partial-write diagnostics not claimed |
| `test` | subset verified | string/integer/file, `!`, `-a`, `-o` | Complete unary/binary ambiguity not claimed |
| `timeout` | local-only | local duration and expiry returned 124 | No published process-group cancellation |
| `touch` | subset verified | create/default update and `-c` | `-d` returned nonzero; timestamp setters unavailable |
| `tr` | subset verified | translate/delete/squeeze/complement/ranges/classes | Verified profile is byte-oriented; locale parity not claimed |
| `true` | subset verified | any args: no output, status 0 | No help path in artifact |
| `uniq` | subset verified | adjacent filtering, `-c -d -u -i`, `-f -s -w -z`, exact count spacing | Fixed C-locale field/character comparison; locale collation not claimed |
| `wc` | subset verified | `-l -w -c -m -L`, combinations, aligned multi-file totals, `--files0-from`, files/stdin | `-L` is the C-locale display-width profile; full locale diagnostics not claimed |
| `wget` | restricted | Bounded HTTP/HTTPS profile: URL input files; quiet/output/log modes; resume and conditional 304; headers/method/data or binary file bodies; retry classification/delay; redirect limits; content-disposition collisions; connect/read/idle timeouts; HTTP CONNECT proxy/bypass; certificate verification control; HTTP status 8 | Recursive mirroring, cookies/auth/HSTS, FTP and other protocols, post-download timestamp restoration, and exact GNU progress/diagnostic bytes not claimed |
| `xargs` | restricted | whitespace/NUL tokenization, quotes/backslashes, `-0 -r -t -n -L -s -E -I`, `--show-limits`, bounded `-P`; direct-child status classes 123/124/125/126/127 | Child policy required; process windows are bounded and aggregate status deterministically; GNU shell/locale extensions not claimed |
| `xxd` | subset verified | forward hex, `-p -r -c -l`, positive `-s` | Negative/end-relative seek and addressed reverse patching not claimed |

## Help-Visible Only

The following options appeared in the current Wasm `--help` output but are not
called “supported” above because this audit did not exercise a complete
positive result. They are probe targets, not product claims.

| Command | Help-visible only |
| --- | --- |
| `make` | semantic coverage beyond the tested rule/include/recipe slice |
| `sh` | grammar beyond the listed successful slice |
| `sha256sum` | checksum warning/status matrix |
| `xargs` | child status mapping, `-L/-P`, EOF strings, and size/signal rules |

Each row identifies the option families exercised successfully. Explicit
rejections, including `chmod` symbolic/reference modes,
`cp -a/-p`, `ln` hard links, `mkdir` symbolic modes, `sort -R`, timestamp
selectors for `touch`, and negative `xxd -s`, are recorded in their rows.

## Cross-cutting runtime rules

Implicit stdin remains silent and blocks until EOF. Terminal, pipeline,
redirection, and explicit `-` paths use the same byte behavior; no
repository-specific prompt is emitted. The successful quiet paths for `curl`
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
