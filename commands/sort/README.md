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
last resort and remaining ties retain input order. `-s/--stable` suppresses that
whole-record fallback, preserving input order among equal keys. `-u` retains
the first representative under the selected keys.

`-R/--random-sort` or `--sort=random` orders transformed keys by
MD5(seed || effective key), comparing digest bytes and then key bytes on a
digest collision. Equal keys remain together; ordinary record fallback, `-s`,
`-u`, reverse ordering, and local key modifiers still apply. An effective
random key consumes exactly 16 bytes from `--random-source=FILE` before input
processing, even for empty input. Without a source, the public secure random
API supplies the seed. A source named `-` is a literal file. Repeated identical
source paths are allowed; different source strings conflict. A source is not
read when local key comparison modifiers suppress global random ordering.

`-m/--merge` merges already-sorted inputs without checking or repairing their
order. Equal keys keep operand order and then source order with `-s` or `-u`.
It shares the 16-way heap and temporary runs, including additional rounds for
more than 16 operands.

`-o/--output=FILE` writes to a named file with empty stdout; `-o -` names a
literal file. Ordinary sorting consumes all input before truncating the output,
so existing outputs and input aliases are supported. Missing inputs leave an
output uncreated; a later read error can leave a newly created output empty
while retaining an existing output's bytes. Check mode conflicts with output.
Repeated identical output strings are allowed and distinct strings conflict.

Merge accepts new output files. Merge into an existing output is rejected
without mutation: the released filesystem API has no opened-file identity or
descriptor truncation with which to protect aliased merge inputs. Lifting this
boundary requires those public APIs and alias/error-effect regressions.

Records and transformed keys are prepared once before comparison. Sorting uses
a default 64 MiB accounted run budget and at most 16-way heap merges, with
64 KiB input, output and merge buffers. Stable sequence IDs and prepared keys
survive disk runs; `-u` keeps the first representative across run boundaries.
Check mode retains only adjacent records. With no file operand, stdin is read
until EOF.
Spilling requires the host to allow writes in its temporary directory. A denied
temporary write exits 2 before sorted output is emitted, following GNU sort's
fatal-error status; small in-memory input
and check mode do not create disk runs.
Under a Windows sandbox, the host must also provision `TMP` or `TEMP` for
temporary-path lookup; the command preserves the environment supplied by the host.

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
