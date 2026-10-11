# P0 command completion evidence

Date: 2026-09-26

This record covers the first pure MoonBit command-completion batch after the
async 0.22.4 refresh. It records workspace evidence only; the new modules are
not published MoonX releases.

## Implemented packages

`base32`, `cksum`, `mktemp`, `realpath`, `rev`, `tac`, `tree`, `unlink` and `yes` are members of
`moon.work`, use async 0.22.4, and each has a package README, help text and
whitebox regression cases. The shared catalog and compatibility record list
only the documented subsets. Unsupported options reject before command-owned
side effects.

## Checks

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon check --target all --deny-warn
Finished. moon: ran 187 tasks, now up to date

MOON_HOME="$HOME/.moon-accounts/cli" moon test --target native
Total tests: 185, passed: 185, failed: 0.

MOON_HOME="$HOME/.moon-accounts/cli" moon test --target wasm
Total tests: 155, passed: 155, failed: 0.
```

The package tests for each new command passed; the new commands were also
invoked through both Native and Wasm `moon run` entry points. Observed Native
smokes included RFC 4648 encoding, temporary file and directory creation,
existing-path canonicalization, per-line byte reversal and record reversal.
Wasm smokes covered help/entry startup and temporary directory creation. The
final package-level regression pass covered 25 tests across the eleven new
packages on each of Native and Wasm; the workspace Native suite covered 185
tests.

## Boundaries retained

## Unified runner refresh

After adding diagnostic reasons to partial-output contracts and classifying the
tab conversion cases as contracts, the shared runner validated its full active
contract selection on both backends:

```text
Native: 315 semantic passes; boundary and platform skips were reported separately.
Wasm:   315 semantic passes; boundary and platform skips were reported separately.
```

The atime observer was corrected to re-anchor timestamps after content
inspection for both the baseline and final snapshot. This removes the
observer's own read from rejection-side-effect comparisons; the existing
`touch` timestamp boundary now passes without weakening the rejection contract.

`tree` rejects symbolic links because released async exposes kind but not
readlink. `realpath` supports existing targets and rejects missing-path GNU
extensions. `mktemp` uses public entropy plus exclusive creation; it does not
claim timestamp-based uniqueness. `tac` rejects regex separators, and `rev`
uses C-locale byte semantics. `expand` and `unexpand` use C-locale byte columns
and explicitly reject malformed tab-stop lists. These boundaries are documented in the package
READMEs, `docs/compatibility.md`, the catalog and the applicable ADRs.
