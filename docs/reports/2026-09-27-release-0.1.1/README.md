# P0 command release 0.1.1

Date: 2026-09-27

This release republishes the eleven command packages whose README and version
metadata were refreshed. `cli/core` and the original command packages remain at
their existing versions; no core release was required.

The source gate passed on Linux, macOS and Windows in
[CI run 36296273687](https://github.com/moonbit-community/cmd/actions/runs/36296273687).
The candidate manifest validated 58 packages and 404 selected cases. The source
commit was `d3052e1` (`release: prepare new command readmes at 0.1.1`).

The following exact registry coordinates were confirmed through the Mooncakes
manifest API after publication, each with `build_status: success` and both
`0.1.1` and the previous `0.1.0` version retained:

`cli/base32@0.1.1`, `cli/cksum@0.1.1`, `cli/expand@0.1.1`,
`cli/mktemp@0.1.1`, `cli/realpath@0.1.1`, `cli/rev@0.1.1`,
`cli/tac@0.1.1`, `cli/tree@0.1.1`, `cli/unexpand@0.1.1`,
`cli/unlink@0.1.1`, `cli/yes@0.1.1`.

The exact published-consumer smoke used the Native MoonBit release runner:

```text
MOON_HOME="$HOME/.moon-accounts/cli" ./_build/native/release/build/mooxCLI/cmd-tests/release_runner/release_runner.exe \
  --manifest tests/release_runner/published-0.1.1.json --suite smoke --jobs 1 \
  --command base32 --command cksum --command expand --command mktemp \
  --command realpath --command rev --command tac --command tree \
  --command unexpand --command unlink --command yes
```

Result: **22 semantic**, 0 availability, 0 boundary, 0 skipped and 0 failed.
The runner invoked exact `moonx cli/<command>@0.1.1` coordinates and covered
the release cases for all eleven packages. The previous
`published-0.1.0.json` manifest remains frozen for historical replay.
