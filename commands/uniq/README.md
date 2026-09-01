# uniq for moonx

Filter adjacent repeated lines (pipe through sort first for global dedup):

```sh
sort words.txt | moonx cli/uniq
printf 'a\na\nb\n' | moonx cli/uniq -c
```

Options: `-c` prefix occurrence counts, `-d` only repeated lines, `-u` only
unrepeated lines, `-i` case-insensitive comparison.

With no file operand, an interactive terminal receives an EOF waiting prompt;
piped, redirected, and explicit `-` input remain silent.
