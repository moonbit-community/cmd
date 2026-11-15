# Development tools

Run `MOON_HOME="$HOME/.moon-accounts/cli" moon run tools/run.mbtx -- COMMAND`
from the workspace. Keep Moon commands sharing a build directory serial.
The entry resolves repository paths and requires fresh absolute report roots.
See [command validation](../tests/README.md) for execution and result contracts.

`metadata check|update` owns generated option artifacts. Each command declares
its options in `options.json`; the generator preserves parser-table order,
repeatability, attached-value rules and explicit custom adapters. Help layout
is stored separately from the README wording so historical output remains
stable. Custom validators and option precedence stay in command code. Generated
catalog IDs retain their existing semantic bindings and do not establish
upstream compatibility. Support limits and rationale remain manually reviewed.

Command versions come from `moon.mod`. Each driver's `moon.pkg` uses
`dev_build` with `moonbit-community/gen_version@0.0.2` to generate `version.mbt`.
The generated constant ships with the source for published builds; edit the
module version rather than this file. Runtime commands do not read metadata.
There is no separate source-text version check or architecture/naming scanner.

`release/` owns candidate generation and the serial exact-coordinate launcher.
Its tests live beside the tool. Frozen release inputs remain in
[`tests/release`](../tests/release/README.md). No tool publishes packages as a
side effect of preparation, validation or an ordinary push.

Generate the current candidate when preparing a release:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target native tools/release -- --generate-candidate --output tests/release/candidate.json
```

Ordinary development CI validates the registry during actual test execution.
It does not regenerate and compare the release candidate as another gate.

## Tool responsibilities

| Tool | Responsibility and caller |
| --- | --- |
| `run.mbtx` | Public dispatcher for checks, builds, tests and manual workflows. |
| `validate.mbtx` | Launch workspace or published acceptance, record elapsed time and propagate failure. Called by `run.mbtx`. |
| `ci.mbtx` | Select upstream cases, transfer same-run Linux artifacts, aggregate status and summarize report size. Called by development CI. |
| `metadata/` | Generate and check option tables, help, README sections and catalog metadata. `check` runs it in development CI. |
| `release/` | Generate candidate coordinates and launch exact-coordinate MoonX acceptance. Acceptance is a manual workflow. |
| `oracle.mbtx` | Prepare the immutable reference-image profile, version inventory and PSL comparison for Linux differential or published acceptance. |
| `jq_oracle.mbtx` | Offline collector of independent jq runtime and evaluation expectations from a reference image. Ordinary CI does not execute this collector. |
| `http_cookie.mbtx` | Offline collector of Curl/Wget HTTP, Cookie and configuration reference observations. Ordinary CI does not execute this collector. |
| `public_suffix.mbtx` | Generate/check the pinned PSL table and compare it with the oracle. Called by `check` and `oracle.mbtx`. |
| `idna.mbtx` | Generate/check pinned Unicode IDNA tables. Called by `check`. |
| `corpus.mbtx` | Prepare hash-pinned genuine benchmark sources; optionally download them. Called manually or by resource profiles. |
| `benchmark.mbtx` | Build the Native benchmark and correctness tools, then launch the generic timing engine. Called by `run.mbtx benchmark`. |
| `protect.mbtx` | Preserve and compare old/new Wasm artifacts using the registered performance workloads. Manual entry. |
| `resource_profiles.mbtx` | Set up Linux reference tools and dispatch selected resource/timing profiles. Called by the manual resources workflow. |
| `performance.mbtx` | Run the real-corpus timing suite and record its complete verdict. Called by `resource_profiles.mbtx`. |
| `literal.mbtx` | Run grep literal-planner resource shapes with sampled and Linux RSS observers. Called by `resource_profiles.mbtx`. |

The three oracle-related entries serve different stages: environment preparation,
jq corpus collection and HTTP corpus collection. Their independent expected data
must not be regenerated from the candidate during CI. All retained standalone
scripts are type-checked by `check`, including the manual collectors; only the
entries listed as CI callers execute in ordinary development workflows.
