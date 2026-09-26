# expand

The `cli/expand@0.1.0` candidate converts input tab bytes to spaces. It reads standard input
when no file is given and accepts multiple files, preserving every other byte
and each file's boundary exactly.

`-i`/`--initial` converts only tabs before the first nonblank byte on each line.
`-t LIST`/`--tabs=LIST` selects positive, strictly ascending tab stops such as
`4,10,16`; a single stop such as `-t 4` repeats at that width, while tabs after
the final stop of an explicit list become one space. The default stop is 8
columns. Malformed or non-ascending lists are rejected with status 2.

Column tracking follows the C-locale byte stream: newlines reset the column,
backspace moves it one column left, and bytes other than spaces and tabs mark
the line as nonblank for `--initial`.
