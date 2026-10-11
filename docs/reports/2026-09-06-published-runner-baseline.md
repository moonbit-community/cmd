# Published-version runner baseline

Date: 2026-09-06
Language revision: 2026-10-11; historical results retained.

## Runner

`tests/release_runner` is a pure MoonBit published-consumer driver compiled for Native. It reads exact `cli/<cmd>@<version>` coordinates from `manifest.json`, launches `moonx` through the MoonBit process API, and captures stdout, stderr, status and filesystem snapshots in independent fixtures. A pinned Docker oracle provides differential comparison.

`timeout` remains local-only, so the manifest covers 47 commands. It reuses stable shared-runner cases and adds P0 regressions. New releases must update coordinates and option coverage together.

## Classification and gates

The runner distinguishes missing assets, registry transport, candidate failure, oracle failure, semantic mismatch, unexpected side effects, timeout and runner infrastructure failure. Asset and infrastructure failures are not skipped.

Local manifest validation passed: 47 packages and 94 cases, comprising 71 shared base cases and 23 P0/release-specific cases. HTTP cases share one pure MoonBit loopback fixture; HTTPS cases are not selected. Published 0.1.4 assets and P0 fixes entered validation. Affected versions are `echo/false/jqlog/seq/sleep/true@0.1.5` and `sh@0.1.7`, published and accepted by final CI; 0.1.6 is not promoted support.

The first complete smoke executed 94 cases: 71 passed and 23 were classified `registry_transport` after Mooncakes registry read timeouts. There were no `asset_unavailable`, `semantic_mismatch` or `unexpected_side_effect` results. For `sh@0.1.6`, `-s` positional parameters were compared with the pinned POSIX oracle's `sh|shell-name` behavior. Corrected `sh@0.1.7` passed strict differential and cross-platform smoke in workflow `34015767486`.

A local `moonx cli/echo@0.1.5 --version` call returned `Prebuilt wasm asset does not exist`, status 255. Missing assets were therefore not mislabeled as command semantic failures. Docker was unavailable locally; pinned differential execution required Linux CI. This did not prevent manifest validation or runner compilation.
