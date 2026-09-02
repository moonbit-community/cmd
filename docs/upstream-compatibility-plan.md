# Upstream Compatibility Execution Plan

Date: 2026-09-02

This plan implements [ADR 0001](adr/0001-upstream-compatible-command-migration.md).
It is deliberately an execution plan, not a claim that the current 0.1.x
dialect is already upstream compatible.

## Goal

For each published command, make the original command knowledge transferable:
the same documented invocation should produce the same observable behavior for
the declared upstream baseline, except for a proven and prominently documented
pure-MoonBit or Wasm-policy limitation.

Observable behavior means:

- accepted arguments, aliases, defaults, and repeated-option rules;
- stdin consumption and blocking behavior;
- exact stdout and stderr bytes when diagnostics are stable;
- exit statuses;
- filesystem contents, names, timestamps, overwrite behavior, and cleanup;
- process, environment, terminal, and network semantics where applicable.

## Delivery Artifacts

| Artifact | Purpose |
| --- | --- |
| `docs/upstream-baselines.md` | Pin oracle container/image revisions, upstream versions, locale, and platform profile. |
| `docs/compatibility-matrix.md` | One row per command and option group: baseline, status, native/Wasm result, known exception, and fixture IDs. |
| `tests/oracle/` | A native MoonBit fixture runner plus static fixture data. It invokes upstream binaries only in test environments. |
| `tests/fixtures/` | Binary, text, filesystem, process, and local HTTP fixtures. No public-network test dependency. |
| `core/*` changes | Small reusable helpers with package-local tests. |
| `commands/*` changes | Thin option adapters and command-specific policy. |

## Command Completion Ledger

This ledger is the implementation order for all 48 local commands. It is not a
reduced compatibility promise: every row ultimately targets the complete
baseline and remains `partial` until its oracle scope passes.

| Workstream | Commands |
| --- | --- |
| Byte and record | `base64`, `cat`, `head`, `tail`, `tee`, `wc`, `xxd` |
| Line and set transforms | `cut`, `paste`, `nl`, `sort`, `uniq`, `tr`, `comm`, `join` |
| Search, compare, checksum | `grep`, `cmp`, `sha256sum` |
| Formatting and predicates | `printf`, `test`, `seq`, `echo` |
| Paths and read-only filesystem | `basename`, `dirname`, `pwd`, `ls`, `find` |
| Filesystem mutation | `cp`, `ln`, `mkdir`, `mv`, `rm`, `rmdir`, `touch`, `chmod` |
| Environment and process | `env`, `printenv`, `xargs`, `timeout` |
| Language runtimes | `sh`, `make`, `jq`, `jqlog` |
| HTTP transfer | `wget`, `curl` |
| Status-only utilities | `true`, `false`, `sleep` |

The ledger contains every command in the repository exactly once. `timeout`
remains local-only while its process-group capability gate is unresolved;
`jqlog` is measured against its imported source snapshot rather than a system
utility.

## Phase 0: Freeze the Contract

Files: add the two baseline/matrix documents, `tests/oracle/`, and CI setup.

1. Pin GNU Coreutils 9.11, findutils 4.10.0, grep 3.12, Wget 1.25.0,
   curl 8.22.0, GNU Make 4.4.1, jq 1.8.2, and Vim 9.1 `xxd` in a Linux
   oracle image. Use POSIX.1-2024 for `sh` and the imported `jqlog` snapshot.
   Run byte-oriented cases with `LC_ALL=C`, `LANG=C`, `TZ=UTC`, and a
   controlled `PATH`; publish the image digest and every `--version` result.
2. Build a machine-readable case manifest with command, argv, stdin bytes,
   files, environment, expected exit status, and normalization policy.
3. Make the runner execute the upstream binary and the MoonBit binary in
   isolated temporary directories, then compare outputs and side effects.
4. Allow normalization only for intentionally unstable fields such as temporary
   paths and time stamps. Every normalization rule needs a comment and fixture.
5. Seed all 48 commands with a capability/status row: `unmeasured`, `partial`,
   `compatible`, or `exception`. Do not infer `compatible` from current README
   text.

Acceptance: CI can run one fixture end to end and emits a useful byte/exit/
filesystem diff. Rollback: this phase is additive and does not change commands.

## Phase 1: Shared Compatibility Foundations

Files: `core/cli`, `core/platform`, `core/stream`, `core/fsops`, `core/process`,
their tests, and the catalog.

1. Separate generic parser mechanics from upstream command grammar. Commands
   whose grammar is not ordinary getopt keep focused parsers.
2. Introduce a shared diagnostic/exit-status mapping only where an upstream
   family defines common outcomes. Command packages retain ownership of
   wording and status differences.
3. Turn terminal behavior into an explicit policy: prompts and dynamic meters
   appear only when their upstream command would show them and only on a proven
   terminal. Keep pipes and redirects byte-clean.
4. Add filesystem helpers for unique destination naming, create-vs-truncate,
   append, metadata lookup, and atomic cleanup. Preserve the upstream behavior
   rather than applying a generic safety policy that changes semantics.
5. Split process behavior into native-compatibility and Wasm-policy paths.
   Native `env`/`sh`/`make`/`xargs` must not silently discard ordinary inherited
   variables; Wasm remains explicitly policy controlled.

Acceptance: unit tests cover every shared rule and existing command tests stay
green. Rollback: helpers are introduced behind existing call sites first.

## Phase 2: HTTP Transfer Compatibility

Files: `core/netops`, `commands/wget`, `commands/curl`, local HTTP fixtures,
and their READMEs/help snapshots.

1. Add a private, tested URL parser and RFC 3986 relative resolver in
   `core/netops`. Do not use private `moonbitlang/async` functions.
2. Replace the current single-GET path with a streaming transfer state machine:
   request construction, response header handling, redirect policy, body
   streaming, retry classification, destination management, and cleanup.
3. Implement HTTP redirects correctly:
   Wget follows by default with its documented limit; curl follows only with
   `-L`/`--location`. Close every hop, detect loops, and strip sensitive headers
   when the destination origin changes.
4. Implement the shared HTTP options already supported by the MoonBit runtime:
   request headers, request methods, body streaming, proxy configuration, TLS
   verification policy, and response status handling.
5. Make Wget match its output/naming semantics: multiple URLs, `-i`, quiet
   behavior, log routing, `-O` truncation timing, duplicate filename handling,
   retry, resume, timestamping, HTTP error status 8, and progress behavior.
6. Make curl match its output/status semantics: default output to stdout,
   no progress meter mixed with a terminal body, `-s`/`-S`, `-f` status 22,
   `-o`/`-O`, `-L`, `-I`, `-H`, `-X`, `-d` family, uploads, retries, and
   timeout options mapped to their upstream spellings.
7. Create fixtures for 200 fixed/chunked bodies, 301/302/303/307/308, relative
   and cross-origin redirects, loops, 401/403/404/429/500, retries, slow reads,
   connection failure, content disposition, range resume, output collisions,
   and terminal/non-terminal stderr.
8. Before excluding FTP, SFTP, SMTP, and other curl protocols, write separate
   pure-MoonBit feasibility spikes. An unavailable runtime API alone is not a
   final exception without attempting a protocol-level implementation design.

Acceptance: HTTP/HTTPS fixtures compare against Wget 1.25.0 and curl 8.22.0;
the live 302 regression is covered by a local fixture. Rollback: retain the
legacy `netops.fetch` wrapper until both adapters migrate, then remove it in a
separate change.

## Phase 3: Core Text and Data Commands

Files: the relevant `commands/*`, `core/stream`, and oracle fixtures.

Implement in reviewable groups, each with GNU differential tests:

1. Byte and record tools: `base64`, `cat`, `head`, `tail`, `tee`, `wc`, `xxd`.
2. Line transformation tools: `cut`, `paste`, `nl`, `sort`, `uniq`, `tr`,
   `comm`, `join`.
3. Query and formatting tools: `grep`, `cmp`, `sha256sum`, `printf`, `test`,
   `seq`, `echo`, `printenv`.
4. Path and read-only filesystem tools: `basename`, `dirname`, `pwd`, `ls`,
   `find`.
5. JSON and status tools: `jq`, `jqlog`, `true`, `false`, `sleep`.

For each group, compare empty input, binary/NUL input, invalid input, repeated
options, `--`, stdin, multiple files, partial writes, locale-sensitive cases,
and exact exit status. Keep `LC_ALL=C` until a locale data implementation is
separately accepted.

Acceptance: every implemented matrix row passes its GNU oracle cases on Linux
and the native compatibility runner on macOS and Windows where the behavior is
portable. Rollback: one command group per pull request/release candidate.

## Phase 4: Filesystem Mutation Commands

Files: `core/fsops`, `commands/cp`, `ln`, `mkdir`, `mv`, `rm`, `rmdir`,
`touch`, `chmod`, and fixtures.

1. Match normal-file and directory semantics first, including overwrite,
   operand resolution, recursive behavior, diagnostics, and exit status.
2. Spike every missing primitive independently: hard links, readlink,
   symbolic-link preservation, ownership, special files, modes, cross-device
   moves, and timestamp flags.
3. For each unresolved primitive, record the attempted pure-MoonBit approach.
   Only then add an exception to help/README/matrix and fail before side effects.
4. Test Windows separately rather than assuming POSIX filesystem semantics.

Acceptance: destructive fixtures run in disposable directories and prove both
success and no-side-effect failure behavior. Rollback: retain current strict
safety checks until an upstream-equivalent replacement is validated.

## Phase 5: Process and Language Commands

Files: `core/process`, `core/shell`, `commands/env`, `make`, `sh`, `xargs`,
`timeout`, and fixtures.

1. Align `env` inheritance, assignment, unset, command lookup, diagnostics,
   and status with the pinned baseline on native. Document the Wasm policy
   boundary separately.
2. Implement POSIX shell behavior for `sh` incrementally through parser and
   execution fixtures. Do not claim Bash compatibility.
3. Align `xargs` tokenization, replacement, batching, child status, and
   no-input behavior with Coreutils.
4. Align the complete GNU Make 4.4.1 behavior through fixture Makefiles, without
   delegating recipes or the Makefile to host tools.
5. Keep `timeout` behind its process-group capability gate. Revisit only when
   a pure-MoonBit portable group-cancellation primitive is available.

Acceptance: process fixtures have deterministic child programs and verify
environment, signals/cancellation where available, pipelines, and exit codes.
Rollback: preserve the local-only `timeout` publication rule.

## Per-Command Definition Of Done

Before changing any matrix row from `partial` to `compatible`, the owner must
attach a case manifest and CI result proving all of the following for the
declared baseline:

1. every documented short/long option, operand form, alias, `--` boundary, and
   repeated-option rule has a positive and invalid case;
2. implicit stdin, explicit `-`, file operands, pipes, terminal blocking, and
   EOF behavior match without repository-only prompts or output decoration;
3. stdout, stderr, exit status, and error precedence match byte-for-byte except
   for an explicitly justified normalization;
4. successful and failing filesystem/process/network side effects match,
   including no-side-effect failures and cleanup;
5. native Linux, macOS, and Windows results are classified, and Wasm policy
   tests cover every applicable capability boundary;
6. the command README and `--help` contain no undocumented deviation. Any
   accepted exception names its target, limitation, diagnostic, status, and
   safe alternative, and links to the exception spike.

The release candidate is blocked if any command remains `partial` without a
reviewed decision to ship it as such. A compatibility release must publish its
matrix snapshot and oracle-image digest alongside the binaries.

## Phase 6: Documentation, Release, and Publication

Files: command READMEs, `docs/compatibility.md`, catalog data, generated
interfaces, release notes, and module versions.

1. Remove "supported dialect" language only for rows that have passed their
   oracle profile. Retain explicit limitations for all other rows.
2. Make each command's `--help` present the upstream-compatible surface.
   A proven exception appears in help and README with its target/platform and
   safe alternative.
3. Publish no compatibility release from the current 0.1.x line. Cut a new
   minor line after the corresponding matrix scope passes, preserving old
   published versions for rollback.
4. Generate `.mbti` files only with `moon info`; do not edit generated files.
5. Do not run `moon publish` as part of this plan. Publication remains a
   separately reviewed human action.

## Quality Gates

Run after each phase and before a release candidate:

```text
moon check --target all --deny-warn
moon test --target all
moon build --target native --release --deny-warn
moon run --target native tests/compat -- --bin-root _build/native/release/build
moon run --target native tests/policy -- --root .
moon fmt
moon info
git diff --check
```

The oracle job additionally runs the pinned Linux upstream binaries. CI must
exercise native macOS, Linux, and Windows plus the existing Wasm permission
tests. A command cannot move to `compatible` until all applicable jobs pass.

## Exception Gate

Before a semantic weakening is accepted, the pull request must contain:

1. the upstream behavior and a minimal reproducer;
2. the pure-MoonBit designs attempted and why each is unsafe or unavailable;
3. native and Wasm impact;
4. the exact help, README, matrix, diagnostic, and exit-status behavior;
5. a regression test proving the command fails explicitly rather than silently
   doing something different.

This gate is the enforcement mechanism for the requirement that pure MoonBit
is exhausted before compatibility is weakened.
