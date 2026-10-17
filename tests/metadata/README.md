# Metadata contract and backend comparison

Run `MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/metadata/verify.mbtx -- pair`
after building Native and Wasm release artifacts. The existing `native` and
`wasm` modes remain available. `--list` lists registered command probes, and
`--report-dir <fresh-directory>` selects the immutable report destination.

Pair mode executes every registered help/version probe on both backends,
checks each contract, and then compares each captured exit status, stdout byte
and stderr byte. This includes combined-operand and alias probes where defined.
Different help text fails the comparison even if both texts satisfy the help
contract. Missing probe captures fail closed. Reports include separate Native
and Wasm contract rows and a `native+wasm` backend-pair row; successful pair
captures are retained for review. Pair results establish workspace metadata
agreement, not upstream compatibility.

After changing command versions, use a fresh successful pair capture to prepare
the exact published help/version contracts:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/metadata/generate_release_cases.mbtx \
  test-reports/metadata-release-pair
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/metadata/generate_release_cases.mbtx \
  test-reports/metadata-release-pair --write
```

The first invocation validates without writing. The explicit write mode adds
`release-metadata-<command>-help` and `release-metadata-<command>-version` to each
of the 78 releasable command case files and registry selections, and refreshes
the existing standalone version expectations. It checks complete passing
Native/Wasm report rows, byte equality, zero status, empty stderr, the reviewed
help shape, and version output matching the current `moon.mod`. Every capture
must decode as lossless UTF-8 before becoming an exact JSON expectation. Missing
or stale captures fail before writes. The output includes JSON arrays of new and
updated case IDs for the command-by-command coverage declaration.

Adding the catalog's normalized `help` and `version` option identities to these
release profiles is an explicitly reviewed support expansion for this
publication, not an inference from coverage labels. Invocations still use
`--help` and `--version`. Regenerate and validate the candidate after refreshing
the registry.
Generated expectations are preparation inputs: fresh workspace contract/pair
runs and exact-version MoonX acceptance are still required. Historical and
current published snapshots are untouched, and `timeout` remains local-only.
The captures and generated cases use closed stdin; they do not establish that
the command leaves an open input stream unread.
