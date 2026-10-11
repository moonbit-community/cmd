# P2 command release: 0.1.0

Date: 2026-10-11

This release promotes `strings`, `column`, `which` and `date` from the P2
candidate and publishes the catalog changes in `cli/core@0.4.0`. All product
and test code remains pure MoonBit. `timeout` remains local-only.

## Source gate

The source commit was `fafe62fa8581c6123ed2569bffddc35961c81fc4`. GitHub Actions
run [38103982048](https://github.com/moonbit-community/cmd/actions/runs/38103982048)
passed Linux, macOS and Windows. Linux completed Native/Wasm builds, contract
and scenario suites, pinned oracle comparisons, Wasm policy checks, interface
generation and formatting. The contract jobs used one process reader per case
to avoid an infrastructure-only `EAGAIN` failure; the runner's local default
remains four independent cases.

## Registry publication

The account was verified with `MOON_HOME="$HOME/.moon-accounts/cli" moon whoami`
(`cli`). Publication was serialized in the required order. Every upload returned
`Server status: 200 OK`, and `moon view` confirmed the exact immutable version.

| Order | Coordinate | Registry checksum |
| ---: | --- | --- |
| 1 | `cli/core@0.4.0` | `ef1669e0cf46e48137b78a054ad8782d5f37a692a28efdabb4aff0149465eddc` |
| 2 | `cli/column@0.1.0` | `4813a2cb245365677ee8fbeb10a9df70118a6801e2acc473b49a33b2bd3af8e3` |
| 3 | `cli/date@0.1.0` | `d6eecc85f108f58ae0fa30d9171bb736aef4ef93256eef04b17e09934cce64af` |
| 4 | `cli/strings@0.1.0` | `46459923d32fd9a7cbbf9585f7db9f14ae31e3e05683fe63427643d500a38ab5` |
| 5 | `cli/which@0.1.0` | `fdc5a54b2850e97b5ac4cef85b5f1c6ec1bf06b7f30220bff46d1b0c01396974` |

The published manifest is
[`published-2026-10-11.json`](../../../tests/release_runner/published-2026-10-11.json).
Validation passed with 78 package coordinates and 554 selected cases. The
candidate manifest remains frozen at
[`candidate-2026-10-11.json`](../../../tests/release_runner/candidate-2026-10-11.json).

## Exact MoonX acceptance

To ensure the registry assets were usable independently of an existing local
cache, the 78 command asset directories under the CLI account were cleared
before the first full run. The runner then re-downloaded every exact coordinate
from the published manifest. That run recorded 447 semantic passes, 80
availability passes, 23 boundary passes, 3 macOS platform skips and one
registry transport failure for `chmod@0.2.0` (TLS handshake EOF). The `chmod`
asset was downloaded again and its four selected cases passed (1 semantic, 1
availability, 1 boundary and 1 platform skip).

A final full run with all 78 assets present used
`--manifest tests/release_runner/published-2026-10-11.json --suite smoke
--jobs 4` and completed with:

* 447 semantic contract passes;
* 81 availability passes;
* 23 documented boundary passes;
* 3 macOS platform skips, each explicitly marked unsupported on this host;
* 0 failures across 554 selected cases.

The reproducible local report is
`test-reports/published-smoke-20261011-p2-final`. The preceding clean-cache
run is retained at `test-reports/published-smoke-20261011-p2-redownload`, and
the isolated retry is at `test-reports/published-smoke-20261011-p2-chmod-redownload`.
Availability and boundary observations are kept separate from semantic
compatibility, as required by ADR-0001.
