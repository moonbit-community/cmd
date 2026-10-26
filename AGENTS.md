# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- The toplevel directory contains `moon.work`; publishable modules have their
  own `moon.mod`, including `core/moon.mod` and each `commands/<cmd>/moon.mod`.

## Coding convention

- Repository documentation, issue titles/bodies, PR descriptions and new
  explanatory comments must be written in English. Historical document
  translations preserve recorded versions, results and limitations; language
  revisions must not turn old evidence into current acceptance claims.

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Tooling

### Moon tooling and publishing

Use `MOON_HOME="$HOME/.moon-accounts/cli" moon xxx` for every local Moon
command. Keep the current PATH toolchain; do not prepend the account's older
`bin` directory or change the global PATH. Local published-consumer checks use
`MOON_HOME="$HOME/.moon-accounts/cli" moonx cli/<cmd>@<version>` and inherit this
account setting in child launchers. CI uses its own installed toolchain and
environment, without developer account credentials. Never commit
credentials or toolchain cache contents to this repository. The shared
published module is `cli/core`, and command modules are `cli/<cmd>`; verify the
module and version before any release operation.

- `MOON_HOME="$HOME/.moon-accounts/cli" moon fmt` is used to format
  your code properly.

- `MOON_HOME="$HOME/.moon-accounts/cli" moon ide` provides project
  navigation helpers like `peek-def`, `outline`, and `find-references`. See
  $moonbit-agent-guide for details.

- `MOON_HOME="$HOME/.moon-accounts/cli" moon info` is used to update the
  generated interface of the package, each package has a generated interface
  file `.mbti`, it is a brief formal description of the package. If nothing in
  `.mbti` changes, this means your change does not bring the visible changes to
  the external package users, it is typically a safe refactoring.

- In the last step, run `MOON_HOME="$HOME/.moon-accounts/cli" moon info` and
  `MOON_HOME="$HOME/.moon-accounts/cli" moon fmt` to update the interface
  and format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `MOON_HOME="$HOME/.moon-accounts/cli" moon test` to check tests
  pass. MoonBit supports snapshot testing; when changes affect outputs, run
  `MOON_HOME="$HOME/.moon-accounts/cli" moon test --update` to refresh
  snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. For snapshot tests that record
  structured debugging output, derive `Debug` and use `debug_inspect`, rather
  than deriving `Show` for debugging. For solid, well-defined results (e.g.
  scientific computations), prefer assertion tests. You can use
  `MOON_HOME="$HOME/.moon-accounts/cli" moon coverage analyze > uncovered.log` to see which parts of your code are
  not covered by tests.

- Use the same prefix for registry updates, checks, builds, runs and releases:
  `MOON_HOME="$HOME/.moon-accounts/cli" moon update`,
  `MOON_HOME="$HOME/.moon-accounts/cli" moon check --target wasm --deny-warn`,
  `MOON_HOME="$HOME/.moon-accounts/cli" moon build --target wasm --release`,
  `MOON_HOME="$HOME/.moon-accounts/cli" moon run <package>`, and
  `MOON_HOME="$HOME/.moon-accounts/cli" moon publish` from the verified module.
  Preparing a candidate does not authorize publication.

- Serialize workspace check/test/build/info/fmt commands: they share the build
  directory. Agent-authored automation must use pure MoonBit `.mbtx` files.

- A behavior or option change must update the command README, help, shared
  catalog, compatibility record and relevant regression together. Record
  tradeoffs in the existing canonical ADR with an Updated date, evidence and
  conditions for lifting limitations. Keep dated delivery summaries in
  CHANGELOG.md; preserve historical claims and recover full reports from Git.
- Product delivery and required correctness acceptance target Wasm through MoonX.
  Development CI runs the complete applicable Wasm suite on Linux, macOS and
  Windows. Native is retained only for test tools and their own regressions.
- Mainline changes use a PR and the required ubuntu-24.04, macos-15 and
  windows-2025 checks, followed by actual-main validation. Do not bypass branch
  protection. The former C1 coverage audit, change declaration, source/artifact
  sealing and audit-before-push wrapper are retired by the 2026-10-26 CI plan.
  Run relevant local correctness checks before a normal non-force branch push.
- Resource observations and exact-version MoonX acceptance are separate manual
  workflows. Neither runs implicitly on ordinary PRs or main pushes. Publishing
  still requires passing development checks, followed by complete three-platform
  acceptance of the uploaded exact coordinates and Linux upstream comparison.
- Keep current candidate and published expectations separate. latest.json is the
  current published-coordinate authority; acceptance never rewrites the repository.
  Do not republish unchanged commands or generate new historical snapshot chains.
- Retain concise results, stage durations and failure diagnostics. Preserve
  historical evidence in Git without backfill. Missing artifacts, empty required
  selections, deadlines and cleanup/report failures cannot count as success.
- Upstream differential evidence must use a verified immutable oracle profile
  containing the image digest, tool-version inventory, and source or
  distribution checksums. A mutable Docker tag, host PATH tool, handwritten
  source label, availability result, or ordinary contract expectation cannot
  establish upstream parity.
- Standalone `--version` prints exactly `<command> <package-version>` and one
  newline, without an implementation banner. Standalone `--help` starts with
  `Usage: <command>`, includes both metadata options, and ends with a newline.
  Both write to stdout, leave stdin untouched, and exit 0. Preserve frozen
  published expectations when changing workspace metadata contracts.

#### Version evolution and publication order

- Keep an unchanged published command at its current registry version. Bump a
  command only when its source behavior, public API, dependency resolution, or
  documented support profile changes. Do not republish unchanged commands just
  to synchronize another package.
- A newly migrated command with no registry release starts at `0.1.0`, unless
  the release decision explicitly selects another version. Later changes use
  the next unused semantic version. Update `moon.mod`, any package version
  declaration, the package README, help/version output, active and candidate
  manifests, the compatibility record, and the relevant regressions together.
- Publish `cli/core` only when its public API or shared behavior changed. If
  core is unchanged, keep its existing published version and make command
  packages depend on that coordinate. Never create a core release solely to
  force unchanged commands to new versions.
- Before a release, verify the account and exact registry state with
  `MOON_HOME="$HOME/.moon-accounts/cli" moon whoami`, the package version
  listing, and the candidate manifest. A first release must be absent before
  publishing; registry versions are immutable and must never be overwritten.
- Serialize the release pipeline. Commit source, tests, and docs first and
  push that commit once. Wait for the required Linux, macOS, and Windows CI
  checks to pass. Publish `cli/core` first only when core changed, then publish
  changed command packages one at a time in lexical command-name order. After
  every upload require `Server status: 200 OK` and verify the exact registry
  version before moving to the next package. Never run publishes in parallel.
- After all uploads, run exact published-consumer smoke and contract checks
  with `MOON_HOME="$HOME/.moon-accounts/cli" moonx cli/<cmd>@<version> ...`.
  Update the published manifest and CHANGELOG.md with those results, then
  commit and push the documentation. Do not publish from a failing or
  unverified candidate.
- Current registry baseline after the 2026-10-25 R release: core is 0.8.1.
  There are 78 published commands: 37 at 0.2.2, eight at 0.2.3, three at 0.2.0,
  two at 0.2.1, 12 at 0.1.3, ten at 0.1.2, four at 0.1.4, and one each at
  0.2.4 and 0.3.0. Core and seven changed command packages were uploaded;
  the other 71 command versions are unchanged.
  Dependency declarations remain unchanged, including mixed core 0.7.0/0.8.0
  coordinates. `timeout` remains local-only. Exact registry coordinates and
  local-acceptance cases are in tests/release_runner/current/latest.json;
  local MoonX acceptance covers all 78 commands with zero failures. The
  2,135-case run retains 52 explicit boundary results and 22 platform skips;
  ten supplemental find/test/yes functional checks also passed.
  Publication and its local validation
  scope are summarized in CHANGELOG.md under 2026-10-25. This release
  does not establish new cross-platform or final performance acceptance.
  current/published.json retains the previous frozen baseline; earlier
  coordinates remain under tests/release_runner/historical/, including stage 0
  and the 2026-10-11 repair.
  The separate 2026-10-26 manual acceptance run 40270955851 passed all three
  platforms and the full pinned Linux comparison for those same 78 coordinates;
  it did not publish packages or establish formal performance acceptance.
  Update this baseline whenever a later release changes it.

### Mandatory pure MoonBit boundary

- All product code, shared runtime code, command implementations, test runners,
  fixtures, and agent-authored automation in this repository must be written in
  pure MoonBit. Do not add project-owned C, C++, Rust, JavaScript, TypeScript,
  shell, Python, or other language implementations, and do not add FFI or
  native stubs as a workaround for a missing public MoonBit API.
- Host programs are allowed only outside the product boundary for fixed-version
  oracle comparison, test observation, CI setup, and diagnostic collection.
  They must never be delegated to as the implementation of `cli/<cmd>`.
- If a required behavior cannot be implemented through released public MoonBit
  APIs, keep the command or option in an explicit boundary state, record the
  missing API and unlock condition in the applicable canonical ADR and the
  support record, and add a rejection regression test. Historical API-gap
  reports remain immutable; record current unlock conditions in the applicable
  canonical ADR and `docs/compatibility.md`.
