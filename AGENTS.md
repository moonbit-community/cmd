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
  `MOON_HOME="$HOME/.moon-accounts/cli" moon check --target all --deny-warn`,
  `MOON_HOME="$HOME/.moon-accounts/cli" moon build --target native --release`,
  `MOON_HOME="$HOME/.moon-accounts/cli" moon run <package>`, and
  `MOON_HOME="$HOME/.moon-accounts/cli" moon publish` from the verified module.
  Preparing a candidate does not authorize publication.

- Serialize workspace check/test/build/info/fmt commands: they share the build
  directory. Agent-authored automation must use pure MoonBit `.mbtx` files.

- A behavior or option change must update the command README, help, shared
  catalog, compatibility record and relevant regression together. Record
  tradeoffs in the existing canonical ADR with an Updated date, evidence and
  conditions for lifting limitations. Keep historical reports immutable.
- Before every push, if any file under `core/` or `commands/` changes command
  behavior, accepted options or operands, output streams, filesystem/network/
  process effects, capability policy, platform support, dependency resolution,
  metadata, or package version, perform the command-by-command coverage audit.
  The audit must map each changed behavior to a stable registry entry and to
  the required package, contract, scenario, policy, backend-pair,
  upstream-differential, published-differential, or boundary evidence. Record
  affected commands, case IDs, required Native/Wasm runs, oracle profile, and
  any uncovered or deferred boundary. A passing test command or a larger case
  count does not prove coverage completeness. Do not push applicable changes
  while the audit report is missing or the audit returns nonzero. An explicit
  boundary/rejection case must pass the audit with its rejection evidence and
  ADR/support-record unlock condition; it does not bypass the gate. Use the
  reviewed `tests/coverage/push.mbtx` workflow documented in
  `tests/coverage/README.md` to audit and push the exact committed revision.
- Mainline changes must use a PR and the required three-platform checks plus
  `coverage-audit`. Keep `tests/coverage/ci-change.json` current for the complete
  proposed range. It declares impact, never passing results or report paths;
  CI binds real evidence at its exact checked-out revision. Harness-only changes
  still require registered harness regression evidence. Do not bypass branch
  protection or substitute a feature-branch run for the final main commit.
- Round-specific PR bootstrap (2026-10-24): for the current comprehensive
  B2/G/S/D/O/R round, the user authorizes new and corrective feature-branch
  pushes after relevant local correctness passes and the existing C1
  prepare/verify and coverage audit run. Retain nonzero findings for missing
  exact-revision or remote evidence; never label them passing. If `push.mbtx`
  stops on those findings, a non-force direct Git push may bootstrap PR CI.
  This authorization carries across corrective commits without per-SHA
  confirmation. Fix local correctness and scope defects before pushing. All
  three platform checks and `coverage-audit` must pass before merge, followed
  by actual-main validation. Performance and release gates remain unchanged;
  see the optimization plan section 15 and coverage README.
- Verification serves the current workspace and current published coordinates.
  Retain this CI run's reports, required source/artifact/oracle identities and
  failure diagnostics. These identities prevent stale or substituted evidence;
  they are not a requirement to archive every release or recover old images.
  Historical evidence backfill and GitHub Release verification archives are
  outside the test system's maintenance scope.
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
  Update the published manifest and release report with those results, then
  commit and push the documentation. Do not publish from a failing or
  unverified candidate.
- Current registry baseline after the 2026-10-25 command release: core is 0.8.0.
  There are 78 published commands: 38 at 0.2.2, seven at 0.2.3, five at 0.2.0,
  14 at 0.1.3, 11 at 0.1.2, and one each at 0.1.4, 0.2.4 and 0.3.0.
  Core and 76 command packages were uploaded; curl and wget retain 0.2.3.
  Dependency declarations remain unchanged, including mixed core 0.7.0/0.8.0
  coordinates. `timeout` remains local-only. Exact registry coordinates and
  local-acceptance cases are in tests/release_runner/current/latest.json;
  full local MoonX acceptance is pending. Publication and its local validation
  scope are recorded in docs/reports/2026-10-25-command-release.md. This release
  does not establish new cross-platform or final performance acceptance.
  current/published.json retains the previous frozen baseline; earlier
  coordinates remain under tests/release_runner/historical/, including stage 0
  and the 2026-10-11 repair.
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
