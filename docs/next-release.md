# Next Release Notes

The next module release is intentionally gated. Do not publish it until the
three-platform matrix, compatibility runner, Wasm policy runner, stress cases,
and documented command-specific process requirements are all satisfied.

Changes prepared in the source tree:

- freeze a 48-command private compatibility catalog and common option grammar;
- add pure MoonBit compatibility and policy runners;
- stream `wc`, `tr`, `base64`, `nl`, `cut`, `uniq`, and `xxd`;
- incrementally merge `comm`, `join`, and `paste`;
- make filesystem root, nesting, separator, and symlink behavior explicit;
- isolate child cwd and environment through a private process boundary;
- return stable unsupported-capability failures where Windows lacks a portable
  MoonBit operation;
- replace floating CI images with fixed Linux, macOS Intel, and Windows 2025
  runners.

Known release blocker:

- `timeout` does not yet provide its documented process-group cancellation
  behavior and remains unreleasable for harness use. `make`, `sh`, and `xargs`
  require only direct-child wait, status, and cancellation semantics and are no
  longer blocked on process-group support.
