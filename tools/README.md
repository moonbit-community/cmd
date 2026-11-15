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

`structure.mbtx` checks all command entries, responsibility-based file names and
package fixture boundaries. `architecture.mbtx` checks dependency direction,
runtime reachability and registered performance strategies. These structural
checks complement package tests and real Wasm execution; they do not establish
semantic completeness or performance acceptance.

`release/` owns candidate generation and the serial exact-coordinate launcher.
Its tests live beside the tool. Frozen release inputs remain in
[`tests/release`](../tests/release/README.md). No tool publishes packages as a
side effect of preparation, validation or an ordinary push.
