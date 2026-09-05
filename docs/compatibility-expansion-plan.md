# Compatibility Expansion Plan

Status: P0-P9 implementation shipped; audit ledger updated 2026-09-05
Scope: 48 local command modules and the 47 commands exposed by MoonX

This document is both the implementation roadmap and the release audit for the
compatibility work. It records what was delivered, which evidence exists, and
which option-level claims still need independent probes. A parser branch,
`--help` output, or a package test is not a compatibility claim by itself.

The authoritative support record is [`compatibility.md`](compatibility.md).
Pinned upstream versions and the oracle image are in
[`upstream-baselines.md`](upstream-baselines.md). Architectural decisions are
indexed in [`adr/README.md`](adr/README.md).

## Audit Verdict

P0 through P9 are implemented in the current checkout and the unified runner
is the only black-box entry point. The implementation is not being promoted to
full GNU compatibility: each command remains a bounded profile, and the P8
option matrix still contains evidence gaps listed below. This is an intentional
high-standard finding, not a reason to turn a successful parser path into a
support claim.

- The retired `tests/cram`, `tests/compat`, `tests/policy`, and `tests/oracle`
  trees are absent. No compatibility shim or duplicate runner remains.
- Native and Wasm release artifacts are built once and passed to the runner.
  Manifest cases never rebuild commands or start a setup process per case.
- The P8 implementation uses only public `moonbitlang/async/fs` operations plus
  repository MoonBit code. No `async/internal/event_loop`, C stub, custom Wasm
  import, host command delegation, or MoonX-specific adapter was introduced.
- Local checks and the remote pinned-oracle CI run are green. Docker is not
  installed locally, so the pinned oracle was verified remotely only.
- The remaining audit work is targeted certification, not a new architecture:
  close the P8 option gaps before calling the whole P8 table independently
  certified.

## Evidence Baseline

Observed in this checkout on 2026-09-05:

| Check | Result | Interpretation |
| --- | --- | --- |
| `moon check --target all --deny-warn` | Passed | All configured targets type-check without enabled warnings |
| `moon test --target all` | Native 100/100 and Wasm 91/91 passed; JS and Wasm-GC have no test entry | Package tests are green for configured targets |
| Native release build | Passed | One reusable native artifact root exists |
| Wasm release build | Passed | One reusable Wasm artifact root exists |
| Unified `compat` suite | Passed | Native semantics, boundaries, and stress hooks are green |
| Unified `policy` suite | Passed | Wasm authorization and mutation assertions are green |
| Unified manifest validation | 48 commands, 176 semantic cases | Fixture schema and pre-built artifact references are valid |
| Remote pinned oracle | P9 run pending delivery commit | Linux pinned upstream comparison remains a required remote gate; no local Docker oracle is available |
| Local Docker oracle | Not available | Docker is absent; remote CI is the required oracle gate |
| `moon fmt`, `moon info`, `git diff --check` | Passed after this documentation audit | Documentation and generated interfaces are clean |

Manifest case groups are: phase0 4, phase2 17, P1 8, phase3 30, phase4 11,
phase5 17, P2 7, P3 23, P6 5, P7 7, P8 12, and P9 35. The oracle suite
executes all 176 manifest cases; the old claim of 66 cases was stale.

## Stage Reports

Each report names the implementation commit, observable evidence, and the
boundary that remains. Counts are manifest cases, not a claim that every
upstream option has been exhaustively tested.

| Stage | Delivery date | Delivery commit(s) | Delivered surface | Evidence | Remaining boundary | Audit result |
| --- | --- | --- | --- | --- | --- | --- |
| P0 | 2026-09-04 | `1953490` | Unified `compat`, `oracle`, and `policy` suites; pre-built artifact roots; retired tree removal | Current 176-case manifest validates; native and policy suites pass; remote oracle green | Local Docker oracle unavailable | Complete |
| P1 | 2026-09-04 | `0094682` | Bounded HTTP/HTTPS `curl` and `wget` controls, retries, redirects, bodies, proxy and TLS policy | 25 HTTP manifest cases (phase2 17 + P1 8), reusable local fixtures, Wasm network allow/deny | No FTP/SFTP/SMTP, auth/cookie/config state, or exact progress bytes | Delivered bounded profile |
| P2 | 2026-09-04 | `9a12422` | `grep` context/byte/NUL/recursive/binary surface and `env` aliases, `-C`, precedence, status mapping | 7 P2 manifest cases plus native and policy runner coverage | Full locale classes and complete GNU diagnostics are not claimed | Delivered bounded profile |
| P3 | 2026-09-04 | `9a12422` | Deterministic `sort`, `uniq`, `wc`, and `head` pipeline extensions | 23 P3 manifest cases, C-locale byte tests, retained `tail -F` rejection | No external sort files; `sort -R` and `tail -F` remain rejected | Delivered bounded profile |
| P4 | 2026-09-04 | `625a2d6`, `7307b24` | `find` traversal/actions and `xargs` tokenization, batching, size and bounded `-P` | 11 phase4 manifest cases plus policy child-status cases | Ownership/inode predicates, ambient shell, and unbounded process control remain closed | Delivered bounded profile |
| P5 | 2026-09-04 | `8e254b9` | Restricted POSIX `sh` grammar: substitution, heredoc, conditionals, case, loops, functions, grouping and parameter controls | 17 phase5 manifest cases and Wasm child-policy assertions | Bash-only syntax, job control, arrays, startup files and host-shell delegation remain out of scope | Delivered bounded profile |
| P6 | 2026-09-05 | `ca2f442`, `b684cf1` | Deterministic `jq` CLI modes and imported evaluator boundary | 5 P6 manifest cases, invalid-value cases, imported `jqlog` contract | Not a full jq 1.8.2 language, module or diagnostic claim | Delivered bounded profile |
| P7 | 2026-09-05 | `ca2f442`, `b684cf1` | Bounded `make` conditionals/includes/patterns and `xxd` include/addressed reverse modes | 7 P7 manifest cases with negative parser and offset cases | Jobserver parallelism and negative/end-relative seeks remain rejected | Delivered bounded profile |
| P8 | 2026-09-05 | `fbd2aae`, `083d21d`, `6c3aee6` | Maximum pure-MoonBit Native/Wasm filesystem subset; shared timestamp, overwrite, traversal and platform capability APIs | 12 P8 manifest cases, package tests, native/Wasm policy suite, remote oracle green | Several newly implemented option families lack one-case-per-option differential evidence; see gap register | Implementation shipped; certification incomplete |
| P9 | 2026-09-05 | working tree (to be recorded at delivery) | Remaining low-risk closure: binary/text edge cases, aliases, NUL records, section numbering, status matrices, checksum verification controls, fixed C-locale `tr` classes and escapes | 35 manifest cases, `run_p9_cases` compat group, native/Wasm release runs, policy and GNU-diff gates passed locally; pinned oracle pending final delivery commit | Exact host diagnostics remain compat-only where GNU strings are not stable; no locale beyond fixed C byte profile | Delivered pending final CI |

## Delivered Scope By Stage

This section is the compact implementation report. It preserves the option
families and hard boundaries that were previously scattered across the phase
notes.

### P0: Test System

The unified runner validates the manifest, consumes only pre-built Native/Wasm
roots, captures status/stdout/stderr/filesystem snapshots, and keeps semantic
(`compat`/`oracle`) and authorization (`policy`) failures distinct. The old
black-box trees were deleted rather than wrapped.

### P1: HTTP Transfers

`curl` and `wget` provide the bounded HTTP/HTTPS profile: methods, request
bodies, uploads, output naming, redirects, retries, connect/total/idle
timeouts, HTTP CONNECT proxy selection, no-proxy behavior, and explicit TLS
verification controls. Local HTTP/HTTPS fixtures are reused by the runner.
FTP/SFTP/SMTP, cookies/auth/config state, HTTP/2 negotiation, recursive Wget
mirroring, and exact progress bytes remain outside the profile.

### P2-P3: Text Pipeline

`grep` adds context, byte offsets, NUL records, recursive basename filters, and
binary policies. `env` adds long aliases, `-C`, assignment precedence, and
direct-child status mapping. `sort`, `uniq`, `wc`, and `head` add deterministic
key/field/character controls, numeric/month/version forms, NUL records, check
modes, file-list totals, and count spellings under the fixed C-locale byte
contract. External sorting, locale collation, `sort -R`, and `tail -F` remain
rejected.

### P4: Find/Xargs

`find` supports bounded metadata predicates, `-prune`, `-depth`, safe
postorder `-delete`, and one-child or deterministic batched `-exec`. `xargs`
supports NUL/quoted tokenization, replacement, line/size limits, EOF strings,
`--show-limits`, and bounded `-P` windows. Child launches are direct and
policy-visible; ownership/inode predicates, ambient shells, and unbounded
process control remain closed.

### P5: Shell

The MoonBit interpreter covers command substitution, redirections and
heredocs, conditionals, `case`, `for`/`while`/`until`, functions and `return`,
grouping/subshells, positional/length/shift expansion, and `set -e/-u`.
External commands are explicit child requests. Bash-only syntax, interactive
job control, arrays, startup files, and host-shell delegation are rejected.

### P6-P7: JSON and Language Utilities

`jq` exposes deterministic sort/join/slurp/raw/exit-status/argument/indent
modes alongside the imported evaluator slice; `jqlog` follows its imported
JSONL contract. `make` adds conditionals, includes, pattern rules, automatic
variables, what-if and bounded job behavior. `xxd` adds include output and
addressed reverse patching. Full jq modules/streaming, Make jobserver
parallelism, and negative/end-relative `xxd` seeks remain outside the claim.

### P8: Filesystem

The public filesystem subset includes file kind, regular-file size,
atime/mtime/ctime reads, access checks, symbolic-link creation, nanosecond
comparisons, age buckets, update/interactive/backup decisions, and explicit
`-H/-L/-P` traversal. `test`, `find`, `ls`, `cp`, `mv`, `chmod`, `ln`, and
`touch` fail closed where setters, hard links, `readlink`, special-file
creation, or EXDEV classification are unavailable. The option-level gap
register below is part of this report and must be closed before promotion.

## P9: Remaining Low-Risk Closure

P9 closes the residual command-local gaps from the original plan without
expanding the runtime boundary. The delivered profile is:

| Area | Delivered behavior | Evidence |
| --- | --- | --- |
| `base64` | `-D`, `-i/--ignore-garbage`, strict invalid-input handling and wrap boundaries | P9 manifest and compat cases |
| `basename`/`dirname` | Empty, root, repeated-separator and `--` operand behavior | P9 manifest and compat cases |
| `cmp`/`comm` | Equal/different/error statuses, explicit order diagnostics, NUL records and precedence | P9 compat group; stable status cases in oracle manifest |
| `cat` | Binary passthrough and accepted `-u/--unbuffered` compatibility path | P9 manifest and compat cases |
| `cut`/`paste`/`join` | NUL records, unterminated input handling, delimiter and malformed-list coverage | P9 manifest and compat cases |
| `nl` | Header/body/footer styles, section delimiters, page reset control, starting number and increment | P9 manifest and compat cases |
| `printf`/`seq`/`echo` | Format repetition, descending sequences, byte escapes, and GNU `--` ambiguity | P9 manifest and compat cases |
| `pwd`/`printenv` | Invalid logical `PWD` fallback and mixed present/missing status precedence | P9 compat group |
| `sha256sum` | `--quiet`, `--status`, `--strict`, `--warn`, `--ignore-missing` verification controls | P9 compat group and manifest success case |
| `rmdir`/`rm`/`mkdir`/`tee` | Failure ordering, partial output, and source/target side-effect assertions | P9 compat group |
| `sleep`/`true`/`false` | Argument, help/version, and status paths | P9 compat group |
| `tr` | Fixed `LC_ALL=C` byte classes, `-C`, `-t`, octal escapes, equivalence classes and SET2 repetition | P9 manifest and compat cases |

The P9 runner reuses the already-built Native artifact root. Its local compat
cases intentionally own diagnostic-substring assertions for host-dependent
failure text; the pinned GNU manifest owns byte-for-byte results where the
diagnostic contract is stable. No locale data, host command delegation, or
approximate filesystem behavior is introduced.

## P8 Certification Gap Register

The code and support record expose the following P8 subset. The listed gaps are
the concrete follow-up needed to satisfy the repository definition of done.

| Area | Direct manifest evidence | Missing independent probes |
| --- | --- | --- |
| `test` | `-s`, dangling-link classification | `-L/-h` alias parity, `-N`, `-nt/-ot`, nanosecond equality, and portable positive fixtures for `-p/-S/-b/-c` |
| `find` | `-readable`, `-xtype` | `-amin/-atime/-cmin/-ctime/-mmin`, `-anewer/-cnewer/-newerXY`, `-used`, writable/executable checks, invalid references and repeated predicates |
| `ls` | regular-file `-S` and reverse ordering, dangling-link classification | `-t/-u/-c`, `--time`, `-H/-L/-P` distinctions, executable `-F` marker, and stable tie-break probes |
| `cp` | older-update decision, numbered backup, command-line `-H` | `update=all/none/none-fail`, `-i`, suffix selection, `-L/-P`, cycle and nested-target rejection, and backup/no-side-effect failure paths |
| `mv` | `update=none` | interactive and backup/suffix paths, all update modes, rename failure source preservation, and generated-backup final state |
| `chmod` | closed `=` assignment | invalid and repeated symbolic expressions, multi-class overwrite, directory rejection, and zero-side-effect failures |
| `ln` | relative symbolic link | `-t`, `-T`, interactive and backup/suffix overwrite paths, `--relative` corner cases, and hard-link rejection side effects |
| `touch` | existing create/update and `-c` behavior | explicit negative cases for each rejected timestamp setter and no-content-change assertions |
| Special files | Runtime `FileKind` predicates only | No portable positive fixture exists because the pure MoonBit API cannot create FIFOs, sockets, or block/character devices. Keep these as read-only capability observations, not fabricated success cases. |

Until these probes are added and pass the pinned oracle where applicable, P8
must be described as a shipped bounded implementation with incomplete
option-level certification. This prevents a green smoke suite from hiding
untested aliases, precedence, invalid values, or side effects.

## Unified Test Contract

The runner has three deliberately separate suites:

- `compat`: native command semantics and explicit boundary tests;
- `oracle`: strict differential comparison with the pinned upstream container;
- `policy`: Wasm authorization, mutation, process, and network controls.

Build release artifacts once, then reuse their roots:

```text
moon check --target all --deny-warn
moon test --target all
moon build --target native --release
moon build --target wasm --release
moon run --target native tests/runner -- --manifest tests/fixtures/runner/cases.json --native-root _build/native/release/build --suite compat
moon run --target native tests/runner -- --manifest tests/fixtures/runner/cases.json --native-root _build/native/release/build --suite oracle --oracle-image mooncmd-oracle:phase0
moon run --target native tests/runner -- --manifest tests/fixtures/runner/cases.json --wasm-root _build/wasm/release/build --suite policy
moon run --target native tests/runner -- --manifest tests/fixtures/runner/cases.json --validate-only
moon fmt
moon info
git diff --check
```

The oracle command is run in the pinned Docker job. `--gnu-diff` is an
additional native comparison hook and is Linux-only where the GNU tools are
available. HTTP fixtures are repository-owned; no public network is part of
the contract. MoonX manual validation is not a P8 test stage.

## Evidence Rules

For every newly claimed option, add positive, invalid-value, repeated-option,
`--`, stdin/file, and policy cases when those dimensions apply. Capture exit
status, stdout, stderr, and filesystem side effects. A rejection is evidence
only when it is deterministic and leaves no forbidden mutation. Reuse one
fixture and the pre-built artifacts across a case group.

`compatibility.md` remains the sole support record. `subset verified` means the
listed profile has repeatable evidence; it never means full upstream
compatibility. `restricted` additionally requires an explicit Wasm policy.
`verified rejection` records a supported hard boundary. Help output and source
inspection are never sufficient evidence. The manifest target labels identify
which evidence family has run; they do not replace the support record or the
P8 gap register.

## Permanent Boundaries

The following are intentionally outside the pure Native/Wasm subset: ownership,
inode/link-count/block metadata, long and colour `ls` formats, metadata-
preserving `cp`, arbitrary timestamp setters, hard links, `readlink`, special
file creation, reliable EXDEV classification, recursive Wget mirroring and
non-HTTP protocols, host-shell or host-make delegation, process-group
cancellation for published `timeout`, and locale-sensitive behavior without a
fixed byte-oriented contract. Unsupported forms must fail before partial
mutation.

## Next Closure Work

The immediate next work is independent certification of any remaining P8
filesystem option rows and the P9 remote oracle/policy gates. P9 does not widen
the permanent boundaries below; unsupported setters, ownership, special files,
hard links, and locale-sensitive behavior still fail closed.
