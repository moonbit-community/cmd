# uniq for moonx

Observed native/Wasm profile (2026-09-04): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable unified-runner results and exclusions.

Filter adjacent repeated lines (pipe through sort first for global dedup):

```sh
sort words.txt | moonx cli/uniq
printf 'a\na\nb\n' | moonx cli/uniq -c
```

Options: `-c` prefixes occurrence counts in the GNU seven-column form, `-d`
selects repeated records, `-u` selects unrepeated records, and `-i` folds ASCII
case. `-f/--skip-fields` skips blank-delimited fields before
`-s/--skip-chars`; `-w/--check-chars` limits the compared suffix. `-z` or
`--zero-terminated` switches record input and output to NUL. Selection uses
the fixed `LC_ALL=C` byte profile, including malformed byte input.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.
