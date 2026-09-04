# Command Support Record

Date: 2026-09-03

This is the single support record for the `cmd` repository. It replaces the
former matrix and phase-plan documents. Every claim below comes from a
black-box invocation of a real Wasm executable, with authorization exercised
by the unified runner's policy suite:

```text
moon run --target wasm --release commands/<command> -- <arguments>
```

The audit used temporary fixtures and explicit Wasm policies for process
commands. Source code, unit tests, and the compatibility runner were not used
to infer support. `subset verified` means that the listed invocation and
options produced the stated result; it is not a claim that every upstream
option is implemented. `help-visible only` means the current Wasm artifact
printed the option in `--help`, but the audit did not execute a complete
positive case for that option.

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
| `curl` | restricted | HTTP/HTTPS GET/HEAD/POST; `-sS -f -o -L -I -H`, request data, redirect, and HTTP 404 status 22 | `-X` method semantics, `-O`, successful timeout expiry, retry/proxy/TLS controls, non-HTTP, auth/cookie/config, and exact native diagnostics not claimed |
| `cut` | subset verified | `-c`, `-f`, `-d`, `-s`, range/comma lists | Locale/multibyte/error parity not probed |
| `dirname` | subset verified | multiple operands and `-z` | Remaining path corner cases not probed |
| `echo` | subset verified | `-n`, `-e`, `-E`, escapes | Shell mode ambiguities not probed |
| `env` | restricted | `-i`, `-u`, assignments, direct child launch | `--help` rejected; `-C` depends on policy-visible cwd |
| `false` | subset verified | any args: no output, status 1 | No help path in artifact |
| `find` | restricted | `-name -path -type -mindepth -maxdepth ! -a -o -print -print0`, one-child `-exec ... ;` | Policy required; batching/delete/links/timestamps not verified |
| `grep` | subset verified | `-E -F -i -v -n -c -l -L -q -H -h -x -w -e -f -r` | Binary/locale and full diagnostics not claimed |
| `head` | subset verified | `-n`, `-c`, `-q`, `-v`, files/stdin | `-z` and all count spellings not probed |
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
| `sort` | subset verified | `-r -n -u -f -k -t` | `-i` is rejected by the Wasm artifact; locale/external-sort semantics not claimed |
| `tail` | subset verified | `-n`, `-c`, `+K`, `-q`, `-v`, `-f`/`--follow`, `-s`/`--sleep-interval` | `-f` follows open regular-file descriptors by polling; stdin/pipes stop at EOF; `-F` path-follow and rotation reopen are not claimed |
| `tee` | subset verified | stdin to stdout/files and `-a` append | Signal/partial-write diagnostics not claimed |
| `test` | subset verified | string/integer/file, `!`, `-a`, `-o` | Complete unary/binary ambiguity not claimed |
| `timeout` | local-only | local duration and expiry returned 124 | No published process-group cancellation |
| `touch` | subset verified | create/default update and `-c` | `-d` returned nonzero; timestamp setters unavailable |
| `tr` | subset verified | translate/delete/squeeze/complement/ranges/classes | Verified profile is byte-oriented; locale parity not claimed |
| `true` | subset verified | any args: no output, status 0 | No help path in artifact |
| `uniq` | subset verified | adjacent filtering, `-c -d -u -i` | Field/character skips and locale not claimed |
| `wc` | subset verified | `-l -w -c -m`, combinations, files/stdin | Alignment, `-L`, locale and diagnostics not claimed |
| `wget` | restricted | HTTP/HTTPS, quiet mode, `-O -`, output file, POST request body, HTTP 404 status 8, and invalid idle-timeout rejection | Input/resume/timestamp, header/method edge cases, retry/redirect/proxy/TLS controls, successful timeout expiry, recursive mirroring, cookies/auth/HSTS, non-HTTP, and exact GNU meter not verified |
| `xargs` | restricted | whitespace/NUL tokenization, `-0 -r -t -n -I`; stdin batching | Child policy required; `-L/-P`, EOF strings and full size/signal diagnostics not claimed |
| `xxd` | subset verified | forward hex, `-p -r -c -l`, positive `-s` | Negative/end-relative seek and addressed reverse patching not claimed |

## Help-Visible Only

The following options appeared in the current Wasm `--help` output but are not
called “supported” above because this audit did not exercise a complete
positive result. They are probe targets, not product claims.

| Command | Help-visible only |
| --- | --- |
| `curl` | `-OJ`, `--max-redirs`, `--data-raw`, `--data-binary`, `--data-urlencode`, `-T`, retry/proxy/TLS/removal controls |
| `env` | long aliases and `-C`; `--help` itself is a verified rejection |
| `make` | semantic coverage beyond the tested rule/include/recipe slice |
| `sh` | grammar beyond the listed successful slice |
| `sha256sum` | checksum warning/status matrix |
| `wget` | `-o/-a/-i/-c/-N`, retry/redirect/header/body/proxy/TLS controls |
| `xargs` | child status mapping, `-L/-P`, EOF strings, and size/signal rules |

Each row identifies the option families exercised successfully. Explicit
rejections, including `chmod` symbolic/reference modes,
`cp -a/-p`, `ln` hard links, `mkdir` symbolic modes, `sort -i`, timestamp
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

Build once, then run each case with `moon run --target wasm --release` in an
isolated directory. Pass absolute fixture paths when using `moon -C` so the
project directory cannot be confused with the Wasm working directory. Capture
stdout, stderr, exit status, and side effects independently. Record positive
and negative cases together. Update this record and the command README only
after the black-box result is repeatable.

Per-command decisions are in [`docs/adr/README.md`](adr/README.md). Historical
source provenance and upstream version pins remain in
[`docs/provenance.md`](provenance.md) and [`docs/upstream-baselines.md`](upstream-baselines.md).
