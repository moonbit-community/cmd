# find

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Walk directory trees without following symbolic links. Supports `-name` and
`-path` shell patterns, `-type`, depth limits, negation, AND/OR composition,
and newline or NUL output. `-exec COMMAND ... ;` runs one explicitly parsed
child command per match through the MoonBit process API. This makes `find` a
Restricted-tier command; Wasm hosts must allow both file reads and process
launches. `-exec ... +` and `-exec` combined with OR/negation or a following
action are rejected before traversal; `-delete`, link following, timestamp
predicates, and the remaining expression grammar are incomplete.
