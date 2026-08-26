# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- In the toplevel directory, there is a `moon.mod` file listing module
  metadata.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Tooling

### Moon home and publishing account

All `moon` commands in this repository must use the `mooxCLI` account's
dedicated Moon home. Do not run a bare `moon` command here, because that uses
the default local account and its separate dependency registry.

Use this prefix for every command, including `check`, `test`, `fmt`, `info`,
`package`, `update`, and `publish`:

```bash
MOON_HOME="$HOME/.moon-accounts/moonxCLI" moon <command>
```

The account-specific Moon home also owns its registry index and dependency
cache. When it is new or reports that a registry dependency is missing, update
that same registry before running checks:

```bash
MOON_HOME="$HOME/.moon-accounts/moonxCLI" moon update
```

Never commit credentials or local Moon home contents to this repository. The
published module is `mooxCLI/cmd`; verify the package and version before any
release operation.

- `MOON_HOME="$HOME/.moon-accounts/moonxCLI" moon fmt` is used to format
  your code properly.

- `MOON_HOME="$HOME/.moon-accounts/moonxCLI" moon ide` provides project
  navigation helpers like `peek-def`, `outline`, and `find-references`. See
  $moonbit-agent-guide for details.

- `MOON_HOME="$HOME/.moon-accounts/moonxCLI" moon info` is used to update the
  generated interface of the package, each package has a generated interface
  file `.mbti`, it is a brief formal description of the package. If nothing in
  `.mbti` changes, this means your change does not bring the visible changes to
  the external package users, it is typically a safe refactoring.

- In the last step, run
  `MOON_HOME="$HOME/.moon-accounts/moonxCLI" moon info` and
  `MOON_HOME="$HOME/.moon-accounts/moonxCLI" moon fmt` to update the interface
  and format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `MOON_HOME="$HOME/.moon-accounts/moonxCLI" moon test` to check tests
  pass. MoonBit supports snapshot testing; when changes affect outputs, run
  `MOON_HOME="$HOME/.moon-accounts/moonxCLI" moon test --update` to refresh
  snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. For snapshot tests that record
  structured debugging output, derive `Debug` and use `debug_inspect`, rather
  than deriving `Show` for debugging. For solid, well-defined results (e.g.
  scientific computations), prefer assertion tests. You can use
  `MOON_HOME="$HOME/.moon-accounts/moonxCLI" moon coverage analyze >
  uncovered.log` to see which parts of your code are not covered by tests.
