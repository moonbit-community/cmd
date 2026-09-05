# Oracle and unified runner report

- Historical period: 2026-09-02—2026-09-04
- Scope: upstream baselines, evidence model, and P0 test-system migration
- Status: complete

## Why the runner was rebuilt

The repository previously had separate self-written, differential, and policy
test paths. They did not share fixtures or artifact roots, which made a green
result difficult to interpret and encouraged rebuilding commands inside test
cases. The migration established one runner with three explicit suites:

- `compat`: native command behavior and deterministic boundary tests;
- `oracle`: byte/status/side-effect comparison with a pinned upstream image;
- `policy`: Wasm authorization and mutation tests through `moonrun --policy`.

The runner validates one manifest, consumes pre-built Native/Wasm roots, and
captures status, stdout, stderr, and filesystem effects. The retired
`tests/cram`, `tests/compat`, `tests/policy`, and `tests/oracle` entry points
were deleted rather than wrapped.

## Delivery points

| Commit | Delivery |
| --- | --- |
| `a3f2782` | Upstream compatibility migration definition |
| `89c7579` | Pinned upstream oracle harness and fixtures |
| `62e2c68` | Compatibility foundation and baseline rules |
| `1953490` | Unified `compat`/`oracle`/`policy` runner migration |

The pinned baselines are recorded in
[`../upstream-baselines.md`](../upstream-baselines.md). The runner's artifact
reuse and policy rules are described in
[`../adr/0001-evidence.md`](../adr/0001-evidence.md) and
[`../adr/0002-policy.md`](../adr/0002-policy.md).

## Evidence contract

Each new option family requires positive behavior, invalid values, repeated
options, operand boundaries including `--`, and no-side-effect assertions when
the command mutates files. Native and Wasm evidence are never substituted for
one another. A differential case is promoted only after the pinned upstream
comparison passes; a policy case proves authorization behavior, not GNU
compatibility.

## Result

P0 became the permanent test architecture for all later phases. The manifest
grew from the original migration inventory to the current 176 semantic cases,
while the runner continued to build each target once per suite invocation and
reuse the resulting artifact root.

