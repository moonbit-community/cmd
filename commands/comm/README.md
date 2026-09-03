# comm for moonx

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Compare two sorted files line by line, producing three columns: lines only
in FILE1, lines only in FILE2 (one leading TAB), and common lines (two
leading TABs):

```sh
moonx cli/comm left.txt right.txt
moonx cli/comm -12 left.txt right.txt   # only common lines
```

Options: `-1`, `-2`, `-3` suppress the corresponding column (combinable as
`-12`, `-23`, ...). Use `-` to read stdin. Lines are compared by UTF-16
code units, matching `LC_ALL=C` order for ASCII data.
