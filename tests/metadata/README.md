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
