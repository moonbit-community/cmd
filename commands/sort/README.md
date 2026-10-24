# sort for moonx

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Sort lines of files or stdin:

```sh
moonx cli/sort names.txt
printf '10\n2\n' | moonx cli/sort -n
moonx cli/sort -t, -k 2 -u data.csv
```

Options include `-r`, `-u`, `-b`, `-d`, `-f`, and `-i`, plus `-n` numeric,
`-g` general numeric, `-h` human numeric, `-M` month, and `-V` version
comparisons. Repeated `-k F[.C][OPTS][,F[.C][OPTS]]` keys support field,
character, and local comparison modifiers; `-t BYTE` selects a field
separator. `-z` selects NUL records. `-c/--check` diagnoses the first disorder
and `-C/--check=quiet` only returns status 1.

Comparison uses C-locale byte rules without changing environment variables.
Blank-separated fields retain their leading separator run unless `-b` applies;
case folding maps lowercase ASCII to uppercase, and human numeric order compares
sign, suffix magnitude, then numeric value. Key ties use the whole record as the
last resort and remaining ties retain input order. `-R` is recognized but
rejected before reading input because the package has no audited deterministic
seed contract.

Records and transformed keys are prepared once before comparison. Sorting uses
a default 64 MiB accounted run budget and at most 16-way heap merges, with
64 KiB input, output and merge buffers. Stable sequence IDs and prepared keys
survive disk runs; `-u` keeps the first representative across run boundaries.
Check mode retains only adjacent records. With no file operand, stdin is read
until EOF.
Spilling requires the host to allow writes in its temporary directory. A denied
temporary write fails before sorted output is emitted; small in-memory input
and check mode do not create disk runs.

The run budget counts record/key payloads, entry/key slots, sequence IDs and
reserved merge buffers/index space. It is not an RSS cap: the active input
record, unique-key retention, allocator/GC overhead and oversized individual
records can add storage. Oversized records are processed without truncation.
Temporary directories and files are created exclusively with restrictive
permissions and removed on normal completion or propagated errors; this does
not promise cleanup after an unobservable crash or SIGKILL.

## Standalone metadata

Standalone `--version` prints exactly `sort 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: sort`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
