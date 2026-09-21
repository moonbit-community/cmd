# Test cleanup implementation, 2026-09-21

Status: local 0.2.0 candidate; not published. This report is updated with the
final verification below. Historical audit reports and published manifests are
retained as evidence rather than rewritten to match the candidate.

## Baseline and reproducibility

Local Moon invocations use `MOON_HOME="$HOME/.moon-accounts/cli" moon ...`, with
the existing PATH toolchain (moon/moonrun 0.1.20260915, moonc
0.10.13+cbb11c36f). Dependencies remain async 0.22.1, x 0.5.5 and moonjq 0.1.2.
The account's older bin directory is not added to PATH. CI uses its own setup.

The pre-change Native package suite passed 132/132. The attempted Wasm baseline
overlapped ls source edits and encountered a transient compile error; it is not
a valid old-version product failure or a usable timing baseline. The earlier
119/119 Wasm result belongs to the previous fidelity report. Baseline inventories,
toolchain output and frozen-manifest hashes are in
`2026-09-21-test-cleanup-evidence/`.

No trustworthy same-condition elapsed-time baseline was captured before this
refactor. Consequently this change makes no percentage speedup claim. Per-case
durations now appear in JSONL reports. The unchanged Native compatibility
assertions completed in 27,608 ms on this Mac after migration; this is one
observation, not a cross-platform benchmark.

## Implemented changes

- AGENTS.md now specifies the account prefix for every local Moon command and
  MoonX verification, serialized workspace tooling, `.mbtx` automation, and
  synchronized README/help/catalog/tests/ADR maintenance.
- Both runners share case types, text/hex decoding, fixture creation, path checks,
  HTTP fixtures, normalization, byte comparisons, metadata snapshots, selection,
  contract checks, process capture and report serialization in testkit.
- Results distinguish pass/fail/skip/infra from availability/contract/
  differential/boundary. Smoke success is an availability pass. Skips, boundary
  checks and availability are excluded from semantic passes. Coverage is based
  on selected cases and verified observations.
- Schema 2 stores active cases in per-command JSON files. Frozen schema 1
  manifests remain readable. Input text and hex are mutually exclusive; binary
  and invalid UTF-8 remain hex. Candidate coordinates reference active IDs.
- Single-command contracts execute with bounded concurrency (default 4);
  stateful shell, network, filesystem and lifecycle functions execute serially.
  A failure preserves its work directory and available raw streams. Deadline
  capture retains partial bytes and cancels/waits the directly owned process.
- Metadata is collected before reading contents. Identity is normalized to
  relationships between fixture paths. Fixed atimes are used for ls sorting;
  modification/access times are compared before and after rejected touch calls.
  Missing required metadata is an infrastructure failure, not a semantic pass.
- ls follows command-line links correctly under -H, fixes implicit time sorting
  and sorting precedence, and preserves partial output with failure statuses.
  GNU 9.11 does not accept -P; the project's -P is explicitly an extension.
- jq implements explicit ANSI colors and -M precedence. Twenty-three exact
  contracts come from jq 1.8.2's verified official macOS arm64 binary (SHA256
  `2d75340ba57a4b4b4c8708a21c2dc8e958a48aaa8bba13b27f77f6e4c0eca07e`).
- make's private scheduler test now uses ready/ack semaphores and runs without
  the former Windows early return. CLI recipes use a pure MoonBit helper and a
  separate ready/ack exchange. Both preserve deduplication and failure coverage.

## CI execution changes

Linux, macOS and Windows PR jobs remain. Each has one Native release build and
one Wasm release build; prebuilt runners perform subsequent checks. Linux's
oracle work and candidate validation reuse those artifacts. Linux base compat
runs once, whereas it previously ran once directly and again with `--gnu-diff`.
GNU and stress are separate suites; stress no longer implicitly repeats compat.
Failed jobs upload reports, logs and failed fixtures instead of the whole build
tree. Scheduled/manual published-version and stress gates remain.

## Validation and remaining external gates

- Native and Wasm ls/jq package tests: 13/13 per backend. jq 1.8.2 byte/status/
  stderr differential: 23/23 per backend; ls command contracts: 22/22 per backend.
- Full package tests: Native 152/152 and Wasm 126/126. The last full Native
  run took 147.38 seconds including changed debug links (201.40 user / 8.32
  system seconds); it is not comparable to an uncaptured pre-change timing.
- Full Native compat: all 16 registered cohorts passed. Wasm policy passed.
  The portable contract/scenario invocation passed 78 semantic contracts and
  two explicit boundaries per backend. After trace preservation changes, all
  five stateful scenarios passed again on each backend.
- Native/Wasm shell, make and filesystem scenarios passed through the new runner.
  Network scenarios also passed; process lifecycle additionally verifies partial
  timeout capture and a real child returning 124 without a driver timeout.
- Eight actual driver self-check invocations passed: unknown command/case,
  empty suite intersection, list without artifacts, cohort filter, stable alias,
  platform skip and missing oracle. They verify exits 2/0/1 and zero semantic
  promotion for skip/infrastructure outcomes.
- Actual MoonX true@0.1.5 and false@0.1.5 attempts hit registry transport timeouts.
  They produced infra/availability results and exit 1, with zero semantic passes.
  No automatic retry was used. This does not establish published availability.
- Docker is not installed on this Mac. The fixed GNU/Linux oracle and Windows
  execution gates must run in CI; local macOS results do not replace them.
- curl's Secure-cookie exception for loopback HTTP was identified during review
  but has not received a fixed-version oracle probe here. General Secure-cookie
  parity must not be inferred from domain/path/session tests. This is a project
  compatibility edge, not an async API limitation.

0.2.0 remains unpublished. Exact-version MoonX acceptance after an authorized
publication is a separate release gate.

## Migration accounting

The [probe map](2026-09-21-test-cleanup-evidence/probe-migration.md),
[unit map](2026-09-21-test-cleanup-evidence/unit-migration.md),
[case map](2026-09-21-test-cleanup-evidence/case-deduplication.md) and
[compat map](2026-09-21-test-cleanup-evidence/compat-migration.md) identify retained
assertions, layers and backends. Two exactly duplicated active cp definitions
were merged with selectable old-ID aliases. Three standalone active probes were
archived byte-for-byte and replaced by registered scenarios. The network oracle
branch now includes jar-mode comparison in the fixed Linux container; execution
remains an external gate. Temporary migration scripts were removed.

Procedural compat groups are split by subsystem and individually selectable,
but their older multi-command assertions remain in MoonBit. Converting every
one-shot assertion inside those groups to JSON is not complete; keeping those
assertions is preferable to deleting unproven duplicate coverage. This remainder
does not alter the three-platform matrix or classify grouped coverage as
case-specific option certification.

The candidate manifest references 47 unpublished packages and 154 selected
active cases. Historic manifest/base hashes still match the pre-change capture.
No release was attempted. CI now schedules one Native and one Wasm release build
per host, one Linux base compat pass, independent GNU/stress passes and both
backends against the same pinned oracle build. Package debug-test builds remain
separate from release builds. No percentage runtime reduction is claimed.

The final active inventory contains 268 cases in 47 command files, two stable
aliases, five stateful candidate scenarios, one stateful oracle scenario and
19 retained group registrations (16 compat, plus GNU/stress/policy). See
`2026-09-21-test-cleanup-evidence/final-inventory.json`. Nineteen GNU-compatible
ls link/time contracts and all 23 jq color contracts also select the fixed
oracle suite without copying definitions; the three ls -P extension contracts
remain candidate contracts.

Strict Native/Wasm checking and release builds passed. `moon info` and
`moon fmt` were run serially; interface review removed an unintended exported
make scheduler type. Testkit's shared case/report/capture interfaces expanded;
the old runner-local fixture types disappeared. Other product interface changes
belong to the preserved earlier fidelity work. Actionlint, whitespace checks
and candidate manifest validation pass.
