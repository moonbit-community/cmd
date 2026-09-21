# uniq for moonx

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

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
