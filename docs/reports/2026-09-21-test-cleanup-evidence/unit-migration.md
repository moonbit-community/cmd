# Shared mechanism unit-test migration

These are Native driver unit tests. They do not replace command package tests,
real Native CLI tests, Wasm CLI tests or oracle comparisons.

| Former test | Retained test in testkit/fixture_wbtest.mbt | Observations |
| --- | --- | --- |
| runner: hex fixtures preserve arbitrary bytes | Same name | Binary decoding, odd length and invalid digits |
| runner: fixture content expands HTTP placeholders after decoding | Same name | Placeholder expansion, plain bytes and invalid UTF-8 preservation |
| runner: fixture paths cannot escape an isolated work directory | Same name | Empty, absolute and dot-parent traversal, both separators |
| release_runner: release fixture paths stay relative | Merged into the preceding path test | Drive path and symlink target constraints retained; equivalent duplicate traversal assertions merged |
| runner: undeclared normalization preserves binary bytes | Same name | NUL, invalid UTF-8 and line endings preserved without a declared rule |
| runner: working-directory normalization maps local and container roots | Same name | Local fixture and /work normalize identically |
| release_runner: release contract newline checks exactly one terminator | Same name | Empty, missing, single and duplicate newline cases |

Runner-specific byte-difference and suite-selection tests stay in runner;
release manifest, coverage and classification tests stay in release_runner.
No snapshots were updated to turn a failure into success.
