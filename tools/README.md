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

README tables use the two-column layout in
[`docs/readme_template.md`](../docs/readme_template.md). Optional
`readme_options` selects common option IDs from the complete declaration;
omitting it includes all options. This only affects the README, preserving
parser tables, help output and catalog bindings. Run `metadata update` after
changing the selection or wording, then `metadata check`.

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
| `ci.mbtx` | Select upstream cases, hand off prepared Linux artifacts from this run's producer, and summarize report size. Called by development CI. |
| `metadata/` | Generate and check option tables, help, README sections and catalog metadata. Linux runs it through `check inputs`. |
| `release/` | Generate candidate coordinates and launch exact-coordinate MoonX acceptance. Acceptance is a manual workflow. |
| `oracle.mbtx` | Prepare the immutable reference-image profile, version inventory and PSL comparison for Linux differential or published acceptance. |
| `public_suffix.mbtx` | Generate/check the pinned PSL table and compare it with the oracle. Called by `check` and `oracle.mbtx`. |
| `idna.mbtx` | Generate/check pinned Unicode IDNA tables. Called by `check`. |
| `corpus.mbtx` | Prepare hash-pinned genuine benchmark sources; optionally download them. Called manually or by resource profiles. |
| `benchmark.mbtx` | Build the Native benchmark and correctness tools, then launch the generic timing engine. Called by `run.mbtx benchmark`. |
| `protect.mbtx` | Preserve and compare old/new Wasm artifacts using the registered performance workloads. Manual entry. |
| `resource_profiles.mbtx` | Set up Linux reference tools and dispatch selected resource/timing profiles. Called by the manual resources workflow. |
| `performance.mbtx` | Run the real-corpus timing suite and record its complete verdict. Called by `resource_profiles.mbtx`. |

The one-time jq and HTTP collectors used for issue #34 and the October 2026
grep literal-planner resource launcher are retired. Their source is preserved
in [Git at c35e7c1](https://github.com/moonbit-community/cmd/tree/c35e7c1aff0e5b976473ae3664106df8f86c79ad/tools).
Captured independent expectations and product regressions remain active.
New reference captures belong to the work that needs them, rather than permanent
CI entry points after that work is complete.

`run.mbtx` launches workspace and published acceptance directly, including timing
and failure reporting. `prepare published` builds the release-profile driver and
launcher once; `CMD_TEST_PREPARED=1` reuses them for oracle setup and acceptance.
Resource profiles build their Native observer once before the selected runs.

Development CI relies on warning-denying builds and tests for product/tool type
checking. Linux additionally runs `check inputs` for standalone scripts and
generated data; local `check` still checks the complete workspace. The metadata
generator runs and tests on Native, with no unused Wasm executable or duplicate
Wasm tool tests. Linux exports
its prepared artifacts before package and functional tests. The upstream job
waits for the latest producer attempt's artifact, then prepares the image and runs comparisons
while correctness continues. The workflow expression combines both job results
without another toolchain installation. Only main saves compilation and Docker
caches; other branches may restore them.
Consumer-only retries can reuse the same run's earlier producer artifact;
full retries wait for their new producer. Import still checks source, toolchain
and artifact bytes before execution.
Report artifacts also include the run attempt, so retries preserve earlier
diagnostics without colliding with immutable artifact names.
