# split

Version **0.1.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates workspace acceptance
from exact published MoonX coordinates.

Split a file or stdin into byte-preserving pieces:

```sh
moonx cli/split -l 100 input.txt part-
moonx cli/split -b 64K -d --additional-suffix=.bin input.bin chunk-
moonx cli/split -n l/3 input.txt part-
moonx cli/split -n r/2/3 input.txt
moonx cli/split -C 4K input.txt part-
```

The default is 1000 records per piece and filenames `xaa`, `xab`, …
`-l/--lines` changes the record count; `-b/--bytes` selects a byte count,
accepting `b`, `K`, `M`, `G`, `KiB`, `MiB`, `GiB`, `kB`, `MB` and `GB`
multipliers. With no first operand, or `-`, input comes from stdin; the
second operand changes the filename prefix. Unterminated and binary records
retain their exact bytes.

`-n/--number` selects one of these layouts:

| Form | Distribution |
| --- | --- |
| N | Divide bytes into N pieces; the first size%N pieces receive one extra byte. |
| K/N | Write only the original Kth byte partition to stdout. |
| l/N | Keep complete records in the partition containing their starting byte. |
| l/K/N | Write only records assigned to the original Kth partition. |
| r/N | Assign complete records cyclically to N pieces. |
| r/K/N | Write only the Kth round-robin stream to stdout. |

N-piece modes create empty files as needed. `-e/--elide-empty-files` omits
them and compresses the generated filename sequence; selected K still refers
to the original partition. Byte and line partitioning uses the named regular
file size when available, otherwise spools input to an owned temporary file.
Round robin reads directly. Empty input in ordinary `-l/-b/-C` modes creates
no output.

`-C/--line-bytes=SIZE` packs complete records within the byte ceiling,
splitting an oversized record only when necessary. It does not fill spare
space after a short complete record with the beginning of a long record.
The record prefix is spooled rather than retained as a whole in memory.
The stream buffer is 64 KiB; temporary disk use for `-C` is at most SIZE,
and unknown-size N-piece input requires a spool of the consumed input.

`-d/--numeric-suffixes[=FROM]` selects decimal names;
`-x/--hex-suffixes[=FROM]` selects lowercase hexadecimal names. Leading
zeroes in FROM do not widen its numeric value. Explicit FROM disables automatic
suffix growth. `-a/--suffix-length` sets a fixed width; zero selects the
default. N-piece modes calculate their required width before opening input.
`--additional-suffix` appends literal text after the generated suffix.
Exhaustion retains completed pieces. Counts use signed 64-bit arithmetic.

Hexadecimal start letters use ordinary base-16 arithmetic: FROM=a produces
0a,0b,0c. GNU 9.11's frozen implementation indexes outside its alphabet when
incrementing a start containing a-f; those memory-dependent names are outside
the upstream comparison profile and are not emulated.

`--filter=COMMAND` runs the existing pure MoonBit shell interpreter once
per named piece, with FILE exported and the exact piece bytes on stdin. It
accepts the shell language already documented by `cli/sh`; it does not
select a host shell through SHELL. Filter stdout and stderr remain inherited.
The catalog classifies split as Restricted because filters can launch external
programs. The host authorizes those children; the classification grants no
process or filesystem permission.
Sequential pieces await EOF and completion before starting the next filter;
round-robin filters remain active together. Empty pieces invoke the filter
unless `-e` suppresses them. A successful filter may ignore stdin.

Filters own their explicit file writes: split does not pre-create or truncate
FILE. Nonzero filter exits propagate with FILE and command diagnostics;
actual SIGPIPE termination is distinguished from a normal exit141. A filter
cannot be combined with a selected K/N stdout stream. Ordinary existing named
outputs remain explicitly refused and unchanged. Read/write/filter failures
retain completed output; owned temporary spools are removed.

## Standalone metadata

Standalone `--version` prints exactly `split 0.1.2` and one newline.
Standalone `--help` starts with `Usage: split`, includes both metadata
options, and ends with a newline. Both write to stdout, leave stdin unread,
and exit 0. Publication and acceptance are recorded separately.
