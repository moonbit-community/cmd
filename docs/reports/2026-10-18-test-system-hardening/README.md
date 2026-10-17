# Current-version test system hardening

This change closes gaps in lifecycle completeness and remote change coverage.
The test system serves the current workspace and current published coordinates.
It does not extend command support, change product APIs or package versions, or
publish more Mooncakes packages.

## Reviewed scope

- Preserve the 26 mandatory proven lifecycle conditions and the explicit
  deferred grandchild-process ownership boundary. Check completeness separately
  from individual registered test bindings.
- Require the same clean Git revision across Linux, macOS, Windows and the
  aggregate coverage audit. PRs use the target base and synthetic merge commit;
  main pushes use the event's before/after range. Regression-only runs do not
  claim change coverage.
- Keep impact in `tests/coverage/ci-change.json` independent of execution
  outcomes. Expand applicable platforms explicitly, including Native-only
  package tests, and reject incomplete or foreign-run evidence.
- When published differential evidence is explicitly required, verify exact
  current coordinates against the fixed Linux oracle. Older expectations cannot
  prove a current behavior whose canonical definition changed.

The pending range also includes the earlier test-system redesign and the already
published metadata contracts. Its impact declaration retains their obligations.
Harness changes add registered regressions and affected scenario/cohort evidence;
case counts alone do not establish coverage.

## Evidence and completion

Local tests provide implementation feedback. Completion requires the PR's three
platform jobs and `coverage-audit`, verified main branch protection, an ordinary
merge commit, and successful checks at the actual merged main SHA. Revalidate the
78 current published coordinates and their 997-case selection, keeping contract,
differential, boundary and platform-skip classifications separate.

CI retains its own reports, necessary identity checks and failure diagnostics.
The [coverage workflow](../../../tests/coverage/README.md) documents the local
audited push and remote aggregation. GitHub Release evidence archives, historical
backfill, per-version recovery catalogs and image restore drills are excluded.
Existing historical reports remain records of their original runs; a Mooncakes
publication record or old pass cannot replace current executable acceptance.

Local validation before the integration commit passed all-target checking with
warnings denied, Native 408/408 tests, Wasm 217/217, wasm-gc 2/2 and JavaScript
2/2. Native and Wasm release builds passed. Generated package interfaces did
not change. These local results are feedback only; the required remote checks
and current-published acceptance remain the completion gates above.
