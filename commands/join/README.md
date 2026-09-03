# join for moonx

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Join lines of two files sorted on their join fields:

```sh
moonx cli/join people.txt colors.txt
moonx cli/join -t, -1 2 -2 1 a.csv b.csv
```

Options: `-1 N` / `-2 N` choose the join field in each file (default 1),
`-t CHAR` field separator (default: runs of blanks, output separated by a
single space). `-a 1|2` includes unpairable rows, `-v 1|2` selects only
unpairable rows, `-e STRING` supplies missing fields, and `-o LIST` selects
join/output fields. The merge streams both sorted inputs and retains only the
current equal-key runs.
