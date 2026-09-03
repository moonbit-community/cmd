# uniq for moonx

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Filter adjacent repeated lines (pipe through sort first for global dedup):

```sh
sort words.txt | moonx cli/uniq
printf 'a\na\nb\n' | moonx cli/uniq -c
```

Options: `-c` prefix occurrence counts, `-d` only repeated lines, `-u` only
unrepeated lines, `-i` case-insensitive comparison.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.
