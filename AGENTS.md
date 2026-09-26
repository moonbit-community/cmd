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
  missing API and unlock condition in `docs/async-upstream-gaps.md` and the
  applicable ADR, and add a rejection regression test.
