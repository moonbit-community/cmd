# nl for moonx

Support note (2026-09-05): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it separates native compatibility evidence from Wasm policy and smoke evidence. Options mentioned here but not promoted in that record are not compatibility guarantees.

Number lines of files or stdin:

```sh
printf 'alpha\nbeta\n' | moonx cli/nl
moonx cli/nl -b a -w 3 -s ' ' notes.txt
```

Options: `-b a|t|n` number all/nonempty/no body lines (default `t`), `-h` and
`-f` select header/footer styles, `-w N` sets number width (default 6), and
`-s SEP` sets the separator (default TAB). `-v N` sets the initial number,
`-i N` its increment, `-d CC` selects the two-byte section delimiter, and
`-p` prevents page resets. `-n ln|rn|rz` selects left, right, or zero-padded
number fields; `-l N` numbers only the last line in each complete group of N
blank lines when style `a` is active. Section markers are replaced by blank
lines. The locale-sensitive `pBRE` numbering style remains outside this fixed
C-locale profile and is rejected.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.
