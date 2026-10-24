# tac

Version **0.1.3** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Write records in reverse order:

```sh
printf 'one\ntwo\n' | moonx cli/tac
printf 'a--b--' | moonx cli/tac -b -s --
```

`-s`/`--separator` selects a fixed separator and `-b`/`--before` places
separators before records. Empty fixed separators mean NUL. Records retain
their original adjoining separator, including a missing final separator.
Ordered file operands insert no extra bytes; `-` consumes stdin. Read/open
failures retain completed output and later operands continue.

`-r`/`--regex` uses the frozen GNU Emacs byte syntax: bare `+`/`?`, escaped
groups/alternation, literal braces, line anchors and buffer assertions. Dot
excludes LF, and POSIX bracket-class syntax is disabled in this dialect.
Search selects the rightmost start and longest end inside the preceding
logical prefix. Nullable patterns make backward progress; an empty regex
rejects before input is opened. Input remains buffered pending the resource
stage; the matcher borrows prefixes without copying the complete remainder.

## Standalone metadata

Standalone `--version` prints exactly `tac 0.1.3` followed by one
newline. Standalone `--help` starts with `Usage: tac`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
