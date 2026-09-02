# find

Walk directory trees without following symbolic links. Supports `-name` and
`-path` shell patterns, `-type`, depth limits, negation, AND/OR composition,
and newline or NUL output. `-exec COMMAND ... ;` runs one explicitly parsed
child command per match through the MoonBit process API. This makes `find` a
Restricted-tier command; Wasm hosts must allow both file reads and process
launches. `-exec ... +` and `-exec` combined with OR/negation or a following
action are rejected before traversal; `-delete`, link following, timestamp
predicates, and the remaining expression grammar are incomplete.
