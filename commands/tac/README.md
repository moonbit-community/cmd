# tac

Version **0.1.4** behavior is documented here. The
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
rejects before input is opened. The matcher borrows prefixes without copying
the complete remainder.

## Large inputs and temporary storage

Fixed separators on regular files are searched backwards in 64 KiB blocks,
including separator matches that cross block boundaries. Selected records are
copied in bounded blocks, so a very long record does not require a record-sized
buffer. Memory is O(block size + separator length); file offsets are 64-bit.
The file is opened once, but concurrent modification is not a snapshot guarantee.
Regular pseudo files whose zero or nominal size disagrees with a positional
end probe are consumed through the stream spool before any output is written.

Standard input and nonregular files are first copied into an invocation-owned
temporary file. Regex mode also uses this spool so matching and output use the
same bytes. Spools require temporary-directory write access and use exclusive
creation with owner-only permissions where supported. The input spool can grow
to the complete input size. No output is written before spooling succeeds;
normal errors and observable cancellation close and remove owned temporary
storage. Process termination that cannot unwind, including SIGKILL, does not
guarantee cleanup.

Regex mode preserves arbitrary-length separator matches. Its current matcher
requires a contiguous byte-view string with 32-bit string indices, retaining
O(input) memory in addition to the disk spool; reversed output is streamed
without a second input-sized output buffer. Bounded-memory arbitrary-span regex
matching requires a shared matcher API over a paged or seekable byte source,
with anchor, overlap and nullable-separator regressions on both backends.
An output error may retain an already written prefix; later operands continue
after an input error, as before.

## Standalone metadata

Standalone `--version` prints exactly `tac 0.1.4` followed by one
newline. Standalone `--help` starts with `Usage: tac`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
