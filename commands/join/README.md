# join for moonx

Support note (2026-09-05): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it separates native compatibility evidence from Wasm policy and smoke evidence. Options mentioned here but not promoted in that record are not compatibility guarantees.

Join lines of two files sorted on their join fields:

```sh
moonx cli/join people.txt colors.txt
moonx cli/join -t, -1 2 -2 1 a.csv b.csv
```

Options: `-1 N` / `-2 N` choose the join field in each file (default 1), `-z`
uses NUL-delimited records,
`-t CHAR` field separator (default: runs of blanks, output separated by a
single space). `-a 1|2` includes unpairable rows, `-v 1|2` selects only
unpairable rows, `-e STRING` supplies missing fields, and `-o LIST` selects
join/output fields. `--check-order` rejects an out-of-order input key;
`--nocheck-order` disables order checks. The default reports disorder when an
unpairable row makes it observable.
The merge streams both inputs and retains only the current equal-key runs.
