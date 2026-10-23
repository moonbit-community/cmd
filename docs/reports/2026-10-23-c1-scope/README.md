# C1 content-bound scope implementation

Base: accepted actual main `4180e527b8673e51dc0127d1747e27f2b3b7e95c`.
Working branch: `codex/comprehensive-c1-scope`.

Status: local implementation and validation; remote C1 acceptance remains
pending. This report does not authorize a bootstrap push, activate scoped
execution, complete C1, publish packages or close feature issues.

## Resulting behavior

The sole `tests/coverage/ci-change.json` migrates to content-bound schema 2.
Generic staged preparation replaces the historical hardcoded generator.
Immutable Git payload/diff records, both dependency graphs, registry, non-import
associations and policy identities determine the automatic minimum. Reviewed
human additions strengthen both old/new applicable requirements. Exact clean
verification detects post-prepare edits, target advancement, lost consumers and
lost additions; a same-tree/base commit-message change needs no artificial edit.

The selector separates reverse consumers from forward build prerequisites,
selects complete changed-command collections, retains removed/moved ownership
and case bindings, recognizes only strictly literal catalog rows, and widens
unknown ownership or resolver semantics to full. Existing rejection conditions
are indexed by stable IDs with current support/ADR/unlock references. Explicit
replacement mappings require actual old and current evidence.

C1 remains `shadow-full`. Every platform executes the full current suite.
Coverage proves the entire current full matrix separately from the shadow's
old-side/extra requirements; replacing an old row cannot replace current
execution. Scheduled/manual/unknown-before full runs derive current requirements
without a fabricated PR diff. Empty summaries and metadata-only receipts cannot
establish completion. Required status names and the existing CI toolchain are
unchanged; C2's coordinator, handoff and weekly activation remain pending.

## Validation and preserved boundaries

The final host run used the existing PATH toolchain, Moon
`0.1.20261021 (a4f8933)` / compiler `0.10.17+093cb8f9c`, with
`MOON_HOME="$HOME/.moon-accounts/cli"`. All-target deny-warn check, interface
generation and targeted formatting passed. All-target tests passed:
Native 580/580, Wasm 287/287, Wasm-GC 2/2 and JS 2/2. The registry contains
1,715 behaviors, including 55 new C1 package tests. Raw command logs are
retained in `/private/tmp/cmd-c1-final-{check,test,info,fmt}.log`.
The current PATH compiler normalizes existing `Int` interfaces to `Int32`;
the fixed CI compiler's actual generated outputs govern the committed
interfaces, preserving unchanged command/core API text.

The pinned CI toolchain, Moon `0.1.20261012 (748b63c)` / compiler
`0.10.15+943464bfa`, also passed the final deny-warn scope/coverage check,
83/83 scope/coverage tests, interface generation, the workflow's harness
formatting and all ten automation formatting checks. The final exported source
archive has SHA-256
`b71b34882967872cda5781fcbda91c7f8f7206e514a07e308870e0e3d9934464`.
Its info/format comparison changed only the 14 generated interfaces expected
from compiler spelling differences, with no source/script formatting drift.
The actual pinned outputs were applied; the 13 existing interfaces match base.

The actual public dependency graph at accepted base has 163 packages and
759 edges, normalized SHA-256
`627671537a16ecb3baed5c10e4f166b2fc4d95e718b9a324ae3e1081fa657b09`.
The C1 package graph has 164 packages and 766 edges, normalized SHA-256
`e58680f29321cbd23b1167567a158724113977b1d90897b60e516b1e30fcea9b`.
Real pinned-CI v2 and host v3 Native/Wasm public graph captures agree for these
resolved imports. Both toolchains also passed actual immutable-snapshot
materialization, cold/warm public resolution and repeated ordinary capture.
All four resulting newline-terminated canonical graph files have SHA-256
`2fc590c0259bf9c7d55e08c8517a55bb94655f43a4b795eff0085295d11f3694`.
The semantic graph digest above excludes the final newline. Recognized official
dependency acquisition progress does not change graph identity; warnings,
unknown progress and malformed logs cannot narrow scope. Two registered
regressions preserve this distinction. Rehearsal inputs, outputs and actual
pinned generated interfaces are retained under
`/private/tmp/cmd-c1-pin15-rehearsal-20261023/`.

The original primary worktree's 13 generated-interface edits and untracked
`docs/algorithm-performance-plan.md` are preserved. C1 changes no command/core
implementation, package version, dependency coordinate or published manifest.
Startup inventory and original pending acceptance conditions are frozen in the
[startup report](../2026-10-23-comprehensive-startup/README.md).

Before the first push, the exact committed candidate must pass fresh local
verification and retain its local audit outcome and pending remote obligations.
The existing policy cannot treat Mac receipts as Windows/Linux evidence. If
that blocks the first migration push, plan section 15 requires a separate
single-branch/single-commit bootstrap authorization. PR merge and actual-main
acceptance still require all three platform statuses plus `coverage-audit`.
