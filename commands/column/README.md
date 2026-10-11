# column

Version **0.1.1**. See the [support record](../../docs/compatibility.md) for release evidence.

Arrange input into columns or an aligned table:

```sh
printf 'one\ntwo\nthree\n' | moonx cli/column -c 40
printf 'name age\nAda 36\n' | moonx cli/column -t
printf 'a:b\ncc:ddd\n' | moonx cli/column -t -s : -o ' | '
```

The default fills columns vertically and separates them with TABs.
`-c`/`--output-width` selects a width; the default is positive `COLUMNS`
or 80. A width of `0` or `unlimited` prints one input record per line.
`-x`/`--fillrows` fills rows first.

`-t`/`--table` aligns fields from all input files in one table.
`-s`/`--separator` supplies a set of delimiter bytes and preserves empty
fields; the default splits runs of space and TAB. `-o`/`--output-separator`
replaces the default two spaces between table columns. Table alignment excludes
complete ANSI color sequences from the display width while preserving their bytes.
Empty input lines are skipped and every output record ends with a newline. Omit file
operands for stdin; a literal `-` is a filename, as in util-linux 2.40.

Layout follows the GNU/Linux C locale: non-ASCII bytes are escaped as
`\xHH`. Non-ASCII input delimiters are rejected. Automatic terminal width,
locale display widths, tree/JSON output and the full util-linux table
grammar are not implemented. `--help` and `--version` are available.
