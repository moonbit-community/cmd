# Exact-version MoonX acceptance

The manual release-acceptance workflow runs full applicable functional checks
on Linux, macOS and Windows, plus pinned upstream comparisons on Linux. It
does not publish packages or modify committed files.

The wrapper invokes the same driver used for workspace Wasm validation. Cases,
assertions, stateful fixtures and permission checks have one implementation.
Every product child uses a coordinate from the selected manifest. Commands
are primed serially and acceptance remains serial within each platform.

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target native --release --deny-warn tests/runner tests/release_runner
MOON_HOME="$HOME/.moon-accounts/cli" ./_build/native/release/build/mooxCLI/cmd-tests/release_runner/release_runner.exe --manifest tests/release_runner/current/latest.json --suite functional --report-dir test-reports/published-functional
```

`functional` is the default. `oracle` selects upstream comparison and `all`
combines both on Linux. Legacy `smoke` is an alias for full functional checks;
`differential` aliases `oracle`. `--command` and `--case` select local diagnostic
subsets; a subset does not establish full publication acceptance.

`current/latest.json` contains current published coordinates and points to
`latest-cases.json`, a separate current expected-case snapshot. Workspace case
edits must not silently change those published expectations. The old
`published.json` and historical files remain recorded evidence and are not
the default inventory.

Candidate generation reads versions from command `moon.mod` files and release
policy from the runtime index:

```text
MOON_HOME="$HOME/.moon-accounts/cli" ./_build/native/release/build/mooxCLI/cmd-tests/release_runner/release_runner.exe --generate-candidate
```

It updates only `current/candidate.json` and `current/active-cases.json`.
After the selected versions are published, dispatch acceptance against the
candidate. Promote successful coordinates and their expectations through a
normal reviewed change. Do not bump or republish unchanged commands merely
to synchronize versions. `timeout` remains local-only.

There is no source-gate run-ID input, receipt sealing, frozen-proof verification
or automatic historical snapshot rotation. Exact package resolution, actual
functional execution, platform applicability and fixed upstream comparisons
remain required. Existing historical snapshots are never rewritten.
