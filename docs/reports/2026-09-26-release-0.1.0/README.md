# P0 command release 0.1.0

Date: 2026-09-26

The three-platform source gate passed in [CI run 36248352909](https://github.com/moonbit-community/cmd/actions/runs/36248352909): Linux, macOS and Windows all succeeded. The gate used the candidate manifest with the original 47 command rows at 0.2.0 and the eleven new rows at 0.1.0.

The following new modules were published sequentially with `MOON_HOME="$HOME/.moon-accounts/cli" moon publish`; every package validation and upload returned `Server status: 200 OK`:

`cli/base32@0.1.0`, `cli/cksum@0.1.0`, `cli/expand@0.1.0`,
`cli/mktemp@0.1.0`, `cli/realpath@0.1.0`, `cli/rev@0.1.0`,
`cli/tac@0.1.0`, `cli/tree@0.1.0`, `cli/unexpand@0.1.0`,
`cli/unlink@0.1.0`, `cli/yes@0.1.0`.

The final published-consumer smoke was run with the exact coordinates through the native MoonBit release runner:

```text
MOON_HOME="$HOME/.moon-accounts/cli" ./_build/native/release/build/mooxCLI/cmd-tests/release_runner/release_runner.exe \
  --manifest tests/release_runner/published-0.1.0.json --suite smoke --jobs 1 \
  --command base32 --command cksum --command expand --command mktemp \
  --command realpath --command rev --command tac --command tree \
  --command unexpand --command unlink --command yes
```

Result: 22 contract observations passed, with zero availability, boundary,
skipped or failed cases. Direct MoonX behavior probes also covered encoding,
checksum, tab expansion, temporary-file creation, path canonicalization, line
and record reversal, tree output, space conversion, unlink and repeated output.

The shared `cli/core` remains at its existing published 0.2.0; unchanged command
packages remain at their existing 0.2.0 versions. `timeout` remains local-only.
