# unexpand

`cli/unexpand@0.2.0` converts runs of spaces to tabs while preserving the
column positions of the input. It reads standard input when no file is given,
accepts multiple files, and preserves all non-space bytes and line boundaries.

By default only leading blank runs are converted. `-a`/`--all` converts runs
after nonblank bytes too. `--first-only` restricts conversion to the first
leading blank run. `-t LIST`/`--tabs=LIST` selects positive, strictly ascending
tab stops and implies `--all`; a single stop repeats at that width, while an
explicit list preserves blanks beyond its final stop. The default tab stop is
8 columns. Invalid lists are rejected with status 2.

Column tracking follows the C-locale byte stream. Existing tabs are preserved
and advance to the next configured stop; backspace moves one column left.
