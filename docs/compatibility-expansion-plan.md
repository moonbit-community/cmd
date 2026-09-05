# Compatibility Expansion Plan

Status: P0-P8 implemented; maximum portable Native/Wasm filesystem subset delivered
Date: 2026-09-05
Scope: the 48 local command modules and the 47 commands currently exposed by MoonX

This document turns the current support record into an execution roadmap. The
P0 test-system migration and the P1-P8 compatibility batches described below
are implemented. P8 consumes public `async/fs` metadata and access primitives,
with shared MoonBit implementations for comparison, traversal, sorting, backup,
interaction, and closed symbolic assignments. It retains explicit rejections
where a setter, hard-link primitive, readlink, special-file creator, or EXDEV
discriminator is unavailable. It
prioritizes the next parameters and behavior families to implement or certify;
it does not change the support claims by itself. A parameter becomes a support
claim only after a repeatable black-box probe against the pinned upstream
baseline passes under the applicable native and Wasm policies.

The authoritative evidence record is [`compatibility.md`](compatibility.md).
Baseline versions and oracle environment rules are in
[`upstream-baselines.md`](upstream-baselines.md). Per-command portability
decisions are in [`adr/README.md`](adr/README.md).

## Executive Recommendation

The recommended order is:

1. Stabilize the unified runner and remove the retired black-box systems.
2. Certify the already-implemented HTTP option surface in `curl` and `wget`.
   Completed in P1 with native semantic, pinned-oracle, and Wasm policy cases.
3. Expand `grep`, then the `sort`/`uniq`/`wc`/`head`/`tail` text pipeline.
   Completed in P2/P3 with native semantics, pinned-oracle cases, and Wasm
   policy coverage.
4. Expand the `find` and `xargs` process-oriented workflow together.
   Completed in P4 with bounded metadata traversal, explicit actions, direct
   child status mapping, and policy-separated process cases.
5. Extend the POSIX subset of `sh`.
6. Add high-value `jq` CLI modes before attempting the full filter language.
7. Extend `make` and the smaller, self-contained `xxd` gaps.
8. Run filesystem capability spikes before attempting metadata-dependent
   options in `chmod`, `cp`, `ln`, `touch`, `ls`, and `mv`. Completed in P8
   with the maximum strict public Native/Wasm subset; unsupported setters and
   link primitives remain closed.
9. Close the remaining low-risk option, diagnostic, locale, and invalid-input
   gaps across the other commands.

This order favors options that are already represented in the parsers and
shared runtime, are frequently used in scripts, and can be tested without
inventing a non-portable Wasm primitive.

## Evidence Baseline

The following results were observed in the current checkout on 2026-09-05:

| Check | Result | Meaning |
| --- | --- | --- |
| `moon check --target all --deny-warn` | Passed | All configured package targets type-check without enabled warnings |
| `moon test --target all` | Native 96/96 and Wasm 87/87 passed; JS and Wasm-GC have no test entry | Package tests are green for configured targets |
| `moon run --target native tests/runner -- --manifest tests/fixtures/runner/cases.json --native-root _build/native/release/build --suite compat` | Passed | Native compatibility suite is green |
| Same runner with `--gnu-diff` | Not run locally | Docker/Coreutils oracle is unavailable in this environment; remote CI remains required |
| Same runner with the pre-built Wasm root and `--suite policy` | Passed | Denied and local-only allowed network policies are green |
| Same runner with `--validate-only` | 48 commands and 141 cases valid | The unified manifest includes the P1-P8 contracts, symlink fixtures, and prebuilt-artifact delay support |

The pinned Docker oracle cannot run locally because Docker is not installed.
The remote pinned-oracle job remains required before this P6-P8 delivery is
accepted; native semantics and Wasm authorization are separate required gates.

The support record intentionally distinguishes `subset verified`, `restricted`,
`verified rejection`, and `help-visible only`. Help output or a parser branch is
not evidence of successful compatibility.

## Priority Model

Each workstream is evaluated on four dimensions:

- **Impact:** how often the command and option family appears in real scripts;
- **Readiness:** how much behavior already exists in the current implementation;
- **Portability:** whether the behavior can remain pure MoonBit and policy-safe;
- **Evidence cost:** how difficult it is to construct deterministic positive,
  negative, and side-effect fixtures.

The plan uses the following delivery labels:

- **Certify:** implementation is likely present; add probes, fix edge cases,
  and update the support record only after the probes pass.
- **Extend:** add parser and semantic behavior, then certify it.
- **Spike first:** determine whether a portable runtime primitive exists before
  committing to an option implementation.
- **Keep bounded:** explicitly retain the current portability boundary when
  upstream behavior would require an unsafe or unavailable primitive.

## P0 - Restore a Trustworthy Regression Gate

This is a prerequisite for every later workstream. It is not a feature batch.

### Unified contract now in force

| Test | Current observation | Required action |
| --- | --- | --- |
| `tests/runner` `compat` | Native contract, boundaries, GNU differential, and stress are one executable suite | Keep all native black-box cases in this suite; pass only a pre-built `--native-root`. |
| `tests/runner` `policy` | Controlled security cases execute Wasm through `moonrun --policy` | Keep authorization assertions separate from semantic assertions; pass only a pre-built `--wasm-root`. |
| `tests/runner` `oracle` | 66 manifest cases compare candidate bytes and side effects with pinned upstream | Add future differential cases to `tests/fixtures/runner/cases.json`; Docker remains an oracle-only dependency. |
| Retired `tests/cram`, `tests/compat`, `tests/policy`, `tests/oracle` | Removed after migration | Do not add compatibility shims or parallel entry points. |

### P0 acceptance

- `compat`, `policy`, and (where Docker is available) `oracle` suites pass from
  the unified runner.
- Every intentional rejection has an assertion for status, diagnostic class,
  and no-side-effect behavior.
- Policy failures are tested separately from parser or semantic failures.
- The runner manifest remains valid and gains a case whenever a differential
  contract is changed for compatibility reasons.

## P1 - HTTP Transfer Controls

**Status:** Implemented on 2026-09-04. The unified runner now has 74 pinned
semantic cases plus reusable native HTTP/HTTPS/proxy fixtures. P1 added the
missing explicit curl method/body redirect distinction and certified the
listed curl/Wget families. Wasm policy coverage includes both denied networking
and a local-only allowed endpoint.

`curl` and `wget` share `core/netops`, already stream HTTP/HTTPS bodies, and
have the largest number of help-visible-but-unverified options. This gives the
highest expected compatibility gain per unit of implementation work.

### P1a - `curl`

**Mode:** Certify, then extend only where a probe fails.

Parameters and behaviors, in order:

1. `-X/--request`: verify every accepted method (`GET`, `HEAD`, `POST`, `PUT`,
   `DELETE`, `CONNECT`, `OPTIONS`, `TRACE`, `PATCH`) and method behavior across
   redirects.
2. `-O/-J` (`--remote-name` and `--remote-header-name`): verify basename
   selection, `Content-Disposition`, collisions, and cleanup on failure.
3. `--data-raw`, `--data-binary`, and `--data-urlencode`: verify repeated data
   ordering, `@file` interpretation, empty values, and binary bytes.
4. `-T/--upload-file`: verify file streaming, missing files, multiple URLs, and
   request method selection.
5. `--retry`, `--retry-delay`, `--retry-max-time`,
   `--retry-connrefused`, and `--retry-all-errors`: verify retryable statuses,
   connection failures, elapsed-time limits, and final status precedence.
6. `--connect-timeout`, `--max-time`, and `--idle-timeout`: verify invalid
   values, zero semantics, successful expiry, and timer-range boundaries.
7. `-x/--proxy`, `--noproxy`, `-k/--insecure`, and `--remove-on-error`: verify
   proxy selection, origin changes, TLS policy, partial output, and cleanup.
8. `--max-redirs`: verify zero, finite, unlimited, loop, and cross-origin
   redirect behavior.

Do not expand this batch to FTP, SMTP, SFTP, cookie/config/auth state, HTTP/2
negotiation, or exact native progress/version bytes. Those require separate
protocol or terminal investigations.

### P1b - `wget`

**Mode:** Certify, then extend.

Parameters and behaviors, in order:

1. `-i/--input-file`: URL list parsing, blank/comment lines, multiple files,
   and per-URL status aggregation.
2. `-o/--output-file` and `-a/--append-output`: log routing, append ordering,
   and quiet-mode interaction.
3. `-c/--continue` and `-N/--timestamping`: range requests, partial files,
   conditional requests, and output preservation after 304/not-modified.
4. `--header`, `--method`, `--body-data`, and `--body-file`: repeated headers,
   request method/body combinations, and binary body handling.
5. `-t`, `--retry-connrefused`, `--retry-on-http-error`, and `--waitretry`:
   retry classification, delay, and final status.
6. `--max-redirect`, `--content-disposition`, and duplicate filename rules.
7. `-T`, `--connect-timeout`, `--read-timeout`, and `--idle-timeout`:
   invalid values and successful inactivity expiry.
8. `--no-check-certificate` and `--no-proxy`: explicit TLS and proxy policy.

Keep recursive mirroring, FTP, authentication/cookies/HSTS, and exact GNU
progress-meter bytes outside this workstream until a separate design is
approved. The current ADR explicitly defines Wget as an HTTP transfer profile.

### P1 acceptance

- Complete: deterministic reusable local HTTP/HTTPS/proxy fixtures cover every
  listed family without rebuilding artifacts or starting one server per case.
- Complete: assertions cover status, stdout, stderr, output files, collision
  names, retry counts, timeout expiry, and cleanup.
- Complete: pre-built Wasm artifacts run under both allowed and denied network
  policies.
- Complete: `compatibility.md`, package READMEs, and ADRs record only the
  bounded HTTP profile established by these probes.

## P2 - High-Frequency Text Matching

### P2a - `grep`

**Mode:** Extend.

Implement and test the options with the highest script value first:

- `-A`, `-B`, `-C` context lines and separator formatting;
- `-b` byte offsets;
- `-s` missing-file/error suppression;
- `-z` NUL records;
- `--include` and `--exclude` recursive selection;
- binary-input behavior and `--binary-files` policy;
- `LC_ALL=C` byte behavior, invalid patterns, and status precedence.

The existing `-E`, `-F`, `-i`, `-v`, `-n`, `-c`, `-l`, `-L`, `-q`, `-H`, `-h`,
`-x`, `-w`, `-e`, `-f`, and recursive paths are already useful. New work must
preserve their current pipeline behavior and filename-prefix rules.

### P2b - `env`

**Mode:** Certify/quick extension.

This is a small, low-risk batch that can land alongside `grep`:

- add and test long aliases for `-i` and `-u`;
- implement `-C/--chdir` with an explicit policy-visible working directory;
- decide whether `--help` is supported or remains a documented rejection;
- compare assignment parsing, unset precedence, command lookup, and statuses
  125/126/127 on native and under Wasm policy.

### P2 acceptance

Every new option gets a positive case, invalid-value case, repeated-option case,
`--` case, stdin/file case where applicable, and native/Wasm policy coverage.

**Implemented 2026-09-04.** `grep` now covers context, byte offsets,
diagnostic suppression, NUL records, recursive basename selection, and binary
policies under the C-locale byte contract. `env` long aliases, `-C`, precedence,
and status mapping are certified; `--help` remains an explicit status-125
rejection. The unified manifest contains the strict differential cases and the
Wasm suite separates filesystem, cwd, and process authorization.

## P3 - Text Pipeline Completion

### P3a - `sort`

**Mode:** Extend while keeping the current bounded in-process design.

Priority order:

1. key modifiers and field handling (`-k` combinations);
2. `-b` blank skipping and `-d` dictionary order;
3. `-g` general numeric, `-h` human numeric, `-M` month, and `-V` version
   comparisons;
4. `-z` NUL records;
5. `-c/--check` and `-C/--check=quiet` validation modes;
6. `-R` random sort only if a deterministic seed contract is defined;
7. `-i` ignore-nonprinting, either as a fully specified implementation or as
   an explicit, tested rejection.

Do not introduce external sorting or temporary-file behavior in this batch;
that is a separate memory and filesystem design under ADR-0016.

### P3b - `uniq`

Add field/character selection and record controls:

- `-f/--skip-fields`;
- `-s/--skip-chars`;
- `-w/--check-chars`;
- `-z/--zero-terminated`;
- exact count-column spacing, malformed-input handling, and locale behavior.

### P3c - `wc`, `head`, and `tail`

- `wc`: add `-L`, NUL file lists, exact alignment, and diagnostics for mixed
  operands.
- `head`: add `-z`, all documented count spellings, and multi-file header
  edge cases.
- `tail`: add `-F` path-follow/rotation reopening only after a portable reopen
  and cancellation contract is tested; retain the current descriptor-follow
  behavior for `-f`.

### P3 acceptance

Use binary/NUL, empty, multiple-file, invalid-value, locale-fixed, and large
input fixtures. The existing `--gnu-diff` subset must remain green.

**Implemented 2026-09-04.** `sort`, `uniq`, `wc`, and `head` implement the
listed deterministic P3 surface with native, oracle, and Wasm-policy evidence.
`sort -R` remains a verified rejection because no deterministic seed contract
exists. `tail -F` remains a verified rejection under ADR-0017 because the
portable file-identity/reopen prerequisite is still unavailable; descriptor
following with `-f` remains the supported behavior. No external sort files or
additional build-per-case paths were introduced.

## P4 - `find` and `xargs` Workflow

**Status:** Implemented on 2026-09-04. `find` now has deterministic metadata
predicates (`-size`, `-empty`, `-mtime`, `-newer`), `-prune`, `-depth`, safe
postorder `-delete`, and one-child or deterministic batched `-exec`. `xargs`
now supports `-L`, `-s`, `-E`, `--show-limits`, and bounded `-P` windows. All
child launches remain direct policy requests; no ambient shell or process-group
authority is introduced. The unified manifest and policy suite contain the
positive, rejection, and side-effect cases for this profile.

These commands should move together because their useful cases are commonly
composed and both cross the Wasm child-process policy boundary.

### P4a - `find`

**Mode:** Extend the bounded expression profile.

1. Make one-child `-exec ... ;` report child failures consistently and test
   allowed versus denied children.
2. Add `-exec ... +` batching with deterministic argument ordering and size
   limits.
3. Add `-prune`, `-depth`, and explicit expression/action precedence.
4. Add `-size`, `-empty`, `-mtime`, `-newer`, and link predicates only after
   the required portable metadata primitives are confirmed.
5. Add `-delete` only with disposable-tree tests, traversal-order tests, and
   no-side-effect failure cases.

Do not silently reinterpret unsupported expressions. Unknown, batched, or
policy-denied forms must fail with a documented status and diagnostic.

### P4b - `xargs`

**Mode:** Extend.

1. Add `-L/--max-lines` and its interaction with `-n` and `-I`.
2. Add `-s/--max-chars` and expose the actual command-size limit used by the
   runtime.
3. Add EOF-string compatibility and explicit `-E` handling.
4. Add `-P/--max-procs` only after concurrent child policy and cancellation
   semantics are defined.
5. Match statuses for ordinary child failure, status 255, signals, missing
   commands, and policy-denied commands.

### P4 acceptance

Fixtures must cover whitespace and NUL tokenization, quotes/backslashes,
replacement, batching, empty input, command-size limits, child status, and
policy denial. No ambient host process authority may be inherited by Wasm.

## P5 - POSIX Shell Surface — Implemented

**Command:** `sh`
**Mode:** Extend incrementally; do not claim Bash compatibility.

Implement in this order:

1. command substitution `$(...)` with nested status and output capture;
2. here-documents and redirection-fed stdin paths;
3. `case` and pattern matching;
4. `for`, `while`, and `until` loops;
5. functions, `return`, and more complete positional/parameter expansion;
6. `set` options and exit-status rules (`-e`, `-u`, and related POSIX forms);
7. compound commands, subshells, grouping, and redirection ordering.

Each grammar addition needs parser tests, an execution fixture, an error case,
and a child-policy case. The interpreter must continue to launch external
commands as explicit child requests; forwarding a script to `/bin/sh` is not an
acceptable compatibility shortcut.

P5 is delivered in the current checkout. The unified runner covers command
substitution, heredocs, conditionals, case patterns, loops, functions/return,
grouping/subshells, parameter length/shift, `set -e/-u`, and policy-visible
child execution. The published claim remains a restricted POSIX slice; Bash
syntax, interactive mode, job control, arrays, and host-shell delegation remain
out of scope.

## P6 - JSON CLI Expansion

P6 is implemented for the CLI-mode slice. The unified manifest now covers
sorting, slurp/raw framing, argument bindings, exit-status mapping, and invalid
option values; the imported evaluator remains separately bounded from a full
jq 1.8.2 claim.

**Command:** `jq`
**Mode:** Extend CLI modes first, evaluator second.

First add the options that unlock common data-processing scripts:

- `-S/--sort-keys`;
- `-j/--join-output`;
- `-s/--slurp`;
- `-R/--raw-input`;
- `-e/--exit-status`;
- `--arg NAME VALUE` and `--argjson NAME JSON`;
- `--indent`, `--tab`, and color/monochrome output only when deterministic
  output rules are specified.

Then extend the filter language in separate slices: arithmetic and comparison
edge cases, `map`/`map_values`, `reduce`, assignments, `try/catch`, modules,
streaming, and error/status parity. Do not label the command “jq-compatible”
for the full 1.8.2 language until the evaluator and diagnostics have their own
oracle suites.

`jqlog` remains a separate imported-contract migration and should not be used
as a proxy for system `jq` compatibility.

## P7 - Language and Self-Contained Utility Gaps

P7 is implemented for the bounded make and xxd slices described below. Jobserver
parallelism and negative/end-relative stream seeks remain explicit boundaries.

### P7a - `make`

**Mode:** Extend, with the existing policy-visible recipe execution.

Prioritize conditionals and graph features before job control:

- `ifeq`/`ifneq`/`ifdef`/`ifndef` and `else`/`endif`;
- pattern and static pattern rules;
- automatic variables beyond `$@` and `$<`;
- built-in variables/rules and environment precedence;
- `-j`, `-k`, `-W`, and failure/parallel status semantics;
- `-include`/`sinclude`, recursive expansion, and secondary expansion.

Every feature needs a Makefile fixture plus a negative case. Recipes remain
explicit child requests under the Wasm policy and are never delegated to a
host `make` executable.

### P7b - `xxd`

**Mode:** Extend; relatively small and self-contained.

- include-style output (`-i`) and all documented aliases;
- negative and end-relative seek semantics;
- addressed reverse patching and offset validation;
- malformed hex, odd-length input, line width, and length boundary parity.

Keep the current positive-seek and forward/reverse byte-stream behavior green.

## P8 - Filesystem Capability Track

P8 is delivered as the maximum strict subset available from public
`moonbitlang/async/fs` on Native and Wasm. `core/fsops` provides nanosecond
timestamp values/comparison and age buckets, update/backup decisions, and
preflighted copy traversal. `core/platform` exposes fine-grained gates while
retaining the historical aggregate predicates.

The delivered command surface includes `test` file kinds/size/access/time
comparisons; `find` a/c/m age and reference predicates, access checks and
`-xtype`; `ls` timestamp/size sorting, link-follow rules and executable
classification; `cp`/`mv` update, interaction and backup controls; `chmod`
closed complete symbolic `=` assignments; and `ln` relative, target-directory,
interaction and backup paths. The unified tests reuse prebuilt artifacts and
exercise policy acceptance and rejection separately.

### Permanent hard boundaries

Mode/owner reads, arbitrary timestamp setters, `cp -p/-a`, hard links,
`readlink`, special-file creation/copy, and cross-device rename classification
remain rejected before mutation. `touch` therefore keeps rejecting arbitrary
timestamp selectors. `ls -l/-i/-s` and full color/ownership formatting remain
outside the portable profile. No internal async event-loop imports, C stubs,
host command delegation, or MoonX-specific adapters are permitted.

`timeout` is deliberately excluded from this track. It remains local-only until
a portable process-group cancellation primitive exists; adding more timeout
flags before that would widen a contract that cannot be published through
MoonX.

## P9 - Remaining Low-Risk Closure

After the higher-impact batches, close the residual gaps in small command-local
changes:

- `base64`: invalid input, aliases, garbage handling, and wrap boundaries;
- `basename`/`dirname`: empty/root/repeated-separator and operand ambiguity;
- `cmp`/`comm`: diagnostics, unsorted input, and all status combinations;
- `cat`: less common GNU flags and binary edge cases;
- `cut`/`paste`/`nl`/`join`: NUL, delimiter, section, locale, and malformed
  input matrices;
- `printf`/`seq`/`echo`: numeric, locale, escape, repetition, and ambiguity
  behavior;
- `pwd`/`printenv`: environment and logical/physical path failures;
- `sha256sum`: checksum-file warnings, malformed records, and status
  precedence;
- `rmdir`/`rm`/`mkdir`/`tee`: diagnostics, failure ordering, and partial-write
  behavior;
- `sleep`/`true`/`false`: all argument, help/version, signal, and status forms;
- `tr`: complete fixed `LC_ALL=C` byte profile before considering locale data.

These are important for completeness but should not displace the workflow and
language commands above unless a new regression raises their priority.

## Shared Oracle and Regression Protocol

Every parameter batch follows the same procedure:

1. Add a manifest case against the pinned upstream version in
   `tests/fixtures/runner/cases.json`.
2. Include a positive case, invalid-value case, repeated-option case, and
   `--`/operand-boundary case where the command grammar permits them.
3. Capture stdout, stderr, exit status, filesystem entries, bytes, selected
   metadata, and child observations independently.
4. Use deterministic local fixtures. Network cases use the repository fixture
   server; process cases use explicit allow-lists; destructive filesystem cases
   use isolated temporary roots.
5. Normalize only declared temporary paths, path separators, working-directory
   roots, or explicitly justified time fields.
6. Run native Linux oracle comparison, then native macOS/Windows compatibility
   checks, then Wasm positive and policy-denied checks.
7. Update the command README, help text, ADR, and support record together.

The following commands are the minimum gate after each workstream:

```text
moon check --target all --deny-warn
moon test --target all
moon build --target native --release --deny-warn
moon build --target wasm --release --deny-warn
moon run --target native tests/runner -- --manifest tests/fixtures/runner/cases.json --native-root _build/native/release/build --suite compat
moon run --target native tests/runner -- --manifest tests/fixtures/runner/cases.json --native-root _build/native/release/build --suite compat --gnu-diff
moon run --target native tests/runner -- --manifest tests/fixtures/runner/cases.json --wasm-root _build/wasm/release/build --suite policy
moon run --target native tests/runner -- --manifest tests/fixtures/runner/cases.json --validate-only
moon fmt
moon info
git diff --check
```

The Docker-backed pinned oracle job is additionally required for any claim
that changes an upstream comparison result. A green smoke runner alone never
promotes a command to full compatibility.

## Definition of Done

A workstream is complete only when:

- all listed options have positive and negative evidence;
- aliases, repetition, `--`, stdin, files, pipes, and EOF behavior are covered;
- stdout, stderr, exit status, and side effects match the pinned profile, or a
  reviewed exception names the exact difference;
- Wasm policy behavior is tested separately from command semantics;
- the help text and README do not overclaim unverified behavior;
- generated interfaces are regenerated with `moon info` and reviewed;
- all required native, Wasm, and pinned-oracle gates are green.

Rows in `compatibility.md` remain `partial` until their declared profile is
complete or an ADR exception is accepted. A measured option can be documented
as `subset verified` without implying full upstream compatibility.

## Explicit Non-Priorities

The following are intentionally not on the immediate implementation path:

- publishing `timeout` through MoonX without process-group cancellation;
- silently delegating `sh`, `make`, `curl`, or `wget` to host executables;
- claiming FTP/SFTP/SMTP or recursive Wget mirroring from an HTTP-only design;
- adding metadata-preserving `cp`, symbolic/reference `chmod`, timestamped
  `touch`, or hard-link `ln` beyond the explicit P8 hard boundaries;
- treating locale-sensitive behavior as portable without a fixed locale profile;
- marking a command `compatible` from help output, source inspection, or a
  passing smoke test alone.
