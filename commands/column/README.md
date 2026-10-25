# column

Version **0.1.4**. See the [support record](../../docs/compatibility.md) for release evidence.

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
Blank and whitespace-only input lines are skipped; the first NUL ends the
displayed contents of its input line. Every output record ends with a newline.
Omit file operands for stdin; a literal `-` is a filename, as in util-linux 2.40.

Layout follows the GNU/Linux C locale: non-ASCII bytes are escaped as
`\xHH`. Non-ASCII input delimiters are rejected. Automatic terminal width,
locale display widths, tree/JSON output and the full util-linux table
grammar are not implemented. `--help` and `--version` are available.

Input is read once into a temporary snapshot before layout; later file changes
cannot change the second pass. The snapshot and its index require temporary
filesystem write access. Storage is proportional to the displayed input plus
16 bytes per retained record. Memory retains the longest record, table column
widths and fixed I/O buffers, rather than all input rows or the complete output.
Table and small-grid caches retain at most 1 MiB of record pages and 64 KiB of
index pages. Wide grids select up to 256 pages per cache from the output column
count, raising those limits to 16 MiB and 1 MiB respectively. Pages are allocated
only as read. The snapshot uses two temporary files. A record containing
non-ASCII bytes can expand to four display bytes per input byte. Temporary
files are removed on normal completion, errors and observable cancellation; forced process
termination cannot guarantee cleanup.
An input error preserves already consumed records and continues with later
files. A temporary-file or output failure stops formatting; output may already
contain a prefix once the formatting pass has begun.

## Standalone metadata

Standalone `--version` prints exactly `column 0.1.4` followed by one
newline. Standalone `--help` starts with `Usage: column`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
