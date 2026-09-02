# nl for moonx

Number lines of files or stdin:

```sh
printf 'alpha\nbeta\n' | moonx cli/nl
moonx cli/nl -b a -w 3 -s ' ' notes.txt
```

Options: `-b a|t|n` number all/nonempty/no lines (default `t`), `-w N`
number width (default 6), `-s SEP` separator (default TAB). Unnumbered
lines are indented by the number width. Numbering is continuous across
multiple files.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.
