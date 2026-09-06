# Published-version Runner

`release_runner` is the pure MoonBit release-consumer gate. It runs the exact
`moonx cli/<command>@<version>` entries from `manifest.json`, captures bytes,
status and filesystem effects, and compares them with the pinned oracle. It
never builds command packages inside a case.

Validate the manifest and local package versions:

```text
moon run --target native tests/release_runner -- \
  --manifest tests/release_runner/manifest.json --suite validate
```

`--suite all` is an alias for the full differential run; it keeps the pinned
oracle requirement and does not silently downgrade to smoke.

Run the published differential suite after the registry assets are available:

```text
moon run --target native tests/release_runner -- \
  --manifest tests/release_runner/manifest.json --suite differential \
  --oracle-image mooncmd-oracle:phase0 --report-dir _build/release-report
```

Use `--suite smoke` on platforms without the pinned Docker oracle. Every
invocation uses an explicit package version; `latest`, version ranges and
implicit resolution are rejected. `timeout` is local-only and is intentionally
absent from this manifest.

Cases are sourced from the unified fixture manifest and add release-specific
regressions. HTTP cases share one pure-MoonBit loopback fixture per suite; it
is not started once per case. HTTPS cases are intentionally not selected until
a TLS fixture is pinned. Each promoted option needs a successful case plus boundary,
failure, argument-termination and side-effect coverage. `exact` cases compare
bytes, status and snapshots; `contract` cases compare the documented status,
tokens and newline contract where branding differs from GNU. The P0 `seq FIRST
LAST` descending extension is contract-tested: `seq 3 1` must emit `3`, `2`,
`1`; GNU's default positive-step behavior is not treated as an exact oracle for
that one case.
Cases may set a positive `timeout_ms`; otherwise the CLI `--timeout-ms` default
applies. A timeout is a hard failure, never a skipped case.

The runner reports `asset_unavailable`, `registry_transport`,
`candidate_failure`, `oracle_failure`, `semantic_mismatch`,
`unexpected_side_effect`, `timeout` and `runner_infra` separately. Registry or
fixture failures are hard failures and are never silently skipped.

When publishing a new command version, update `moon.mod`, its package README,
the exact version in `manifest.json`, and the affected case coverage in one
change. Run validation before publishing, then rerun the published suite after
the Wasm asset has finished building.
