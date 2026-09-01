# paste for moonx

Merge corresponding lines of files:

```sh
moonx cli/paste -d, nums.txt letters.txt
moonx cli/paste -s -d, nums.txt   # serial: one output line per file
```

Options: `-d LIST` delimiter characters cycled between columns (default
TAB; `\t`, `\n`, `\0` for empty, and `\\` are understood), `-s` serial
mode. Each `-` argument reads the full stdin content.

With no file operand, an interactive terminal receives an EOF waiting prompt;
piped, redirected, and explicit `-` input remain silent.
