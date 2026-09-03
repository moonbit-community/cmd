# sort for moonx

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Sort lines of files or stdin:

```sh
moonx cli/sort names.txt
printf '10\n2\n' | moonx cli/sort -n
moonx cli/sort -t, -k 2 -u data.csv
```

Options: `-r` reverse, `-n` numeric (by leading number of the key), `-u`
unique by key, `-f` fold case, `-k START[,END]` sort by a field range
(1-based, whole fields), `-t CHAR` field separator (default: runs of
blanks). `-i` is not accepted by the Wasm artifact. Like GNU sort, ties on
the key fall back to comparing the whole line (the "last-resort" rule), and
any remaining ties keep input order; strings compare by UTF-16 code units.
With `-u`, the first line of each equal-key group in sorted order is kept.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.
