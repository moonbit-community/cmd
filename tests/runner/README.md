# Workspace Wasm and published command driver

The Native driver executes either prebuilt Wasm commands or exact published
MoonX coordinates through one shared command launcher. It does not build
commands, fall back to Native products, or substitute host tools for products.

| Suite | Contents |
| --- | --- |
| functional | Metadata, compat, contracts, stateful scenarios, policy and bounded stress correctness |
| metadata | Standalone help/version and existing metadata aliases |
| compat | Catalog, environment, child-command composition, streaming, tail and network cohorts |
| contract | Applicable JSON assertions and explicit rejection boundaries |
| scenarios | Persistent input, filesystem, process and network interactions |
| policy | Wasm/MoonX permissions and supported platform boundaries |
| stress | Bounded output and streaming correctness; no resource sampling |
| oracle | Pinned Linux upstream comparisons |
| all | Functional checks and pinned upstream comparisons |

The default is `functional` with the Wasm backend. `--backend wasm` is accepted
for explicit diagnostic commands. Native and pairing modes are removed.

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target native --deny-warn tests/runner
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target wasm --release --deny-warn
MOON_HOME="$HOME/.moon-accounts/cli" ./_build/native/debug/build/mooxCLI/cmd-tests/runner/runner.exe --suite functional --report-dir test-reports/functional
MOON_HOME="$HOME/.moon-accounts/cli" ./_build/native/debug/build/mooxCLI/cmd-tests/runner/runner.exe --suite contract --command sort --list
```

`--wasm-root` changes the prebuilt artifact directory. `--manifest` changes the
case index. Repeat `--command` and `--case` to select diagnostics; unknown and
empty selections fail. `--report-dir` must be fresh. Normal independent cases
use `--jobs 4`; timestamped, delayed, network and stateful fixtures run serially.
Failures retain bytes and fixture effects. No automatic assertion retries occur.

`--published-manifest FILE --moonx PATH` selects exact coordinates and their
expected case snapshot. Every product child uses the same inventory. The
driver first resolves each selected coordinate serially with a bounded version
probe. Publication diagnostics must use `--jobs 1` through the release wrapper.
The driver never publishes or edits manifests.

Linux `all` checks a contract and its matching upstream comparison using one
candidate invocation when both share the same fixture. Stateful comparisons
retain separate fresh fixtures. `--oracle-image` and `--oracle-profile` must
identify the fixed reference; unavailable references fail as infrastructure.

The process observer records direct-child deadlines, output and cleanup errors.
Container comparisons additionally retain the existing owned-container cleanup
protocol. Report writing failures remain failures; no audit or source sealing
is needed to report actual execution.
