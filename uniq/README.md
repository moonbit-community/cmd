# uniq for moonx

Filter adjacent repeated lines (pipe through sort first for global dedup):

```sh
sort words.txt | moonx mooxCLI/cmd/uniq
printf 'a\na\nb\n' | moonx mooxCLI/cmd/uniq -c
```

Options: `-c` prefix occurrence counts, `-d` only repeated lines, `-u` only
unrepeated lines, `-i` case-insensitive comparison.
