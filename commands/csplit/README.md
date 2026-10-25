# csplit

Version **0.2.1** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Split a file into sections at line numbers or basic regular expressions:

```sh
moonx cli/csplit input.txt 10 20
moonx cli/csplit -s -f section- input.txt '/^Chapter/' '{*}'
```

`NUMBER` splits before that absolute line; `/REGEXP/` splits before a matching
line and `%REGEXP%` discards the preceding section. Regex delimiters may be
followed by a positive or negative line offset. `{N}` repeats the preceding
pattern N additional times. Regex `{*}` repeats through the remaining input;
numeric repetitions that reach beyond the last line report an error.
The first operand `-` reads stdin. All input bytes, including NUL and an
unterminated final line, are preserved in selected fragments.

Files are named `xx00`, `xx01`, … . `-f`/`--prefix` changes the prefix and
`-n`/`--digits` sets the minimum number of suffix digits. Byte counts are printed
for created files unless `-s`/`--silent` or `-q`/`--quiet` is selected.
`-z`/`--elide-empty-files` omits empty fragments. Split failures remove the files
created by that invocation unless `-k`/`--keep-files` is used.

`-b/--suffix-format` replaces the default digits with exactly one d/i/u/o/x/X
integer conversion, literal text and `%%`. Width, precision, left/zero padding
and applicable alternate/thousands flags follow the GNU C profile. Repeated
formats use the last; `-b` determines layout independently of `-n` ordering.
Invalid formats fail before file creation.
Windows ordinary filesystem paths trim trailing spaces and dots. A generated
name with either ending is therefore refused with status 2 before reading
input; it never silently creates a differently named fragment. Verbatim-name
support requires verified Native/Wasm creation, reading and observation of
those exact names.

`--suppress-matched` omits the line at the offset-adjusted split boundary for
regex, ignored regex and numeric patterns. Empty elision reuses the next
output suffix; suppression preserves the separate regex-search cursor.

Input is consumed once into an owned temporary snapshot before creating fragments.
The snapshot and its 64-bit line-offset index stay on disk; each index/data cache
is at most 64 KiB. Numeric splits copy byte ranges in 64 KiB blocks. Regex searches
retain only the current line, so their extra memory includes the largest matched
or searched line, rather than every input record. Temporary disk use is the input
byte count plus eight bytes per line boundary, including the initial boundary.
Created output paths remain in memory for failure cleanup. Regex line storage and
numeric pattern/offset parsing keep their existing signed 32-bit limits; file and
index positions use checked signed 64-bit arithmetic.

The temporary directory and its files are exclusive to the invocation; snapshot
files use mode 0600. They are removed after success, ordinary errors and cancellation
observed by the runtime. A killed process or machine failure cannot guarantee that
cleanup. Temp creation/write or input-read errors occur before fragment creation.
After splitting begins, `-k` keeps completed or partial fragments; without it,
the invocation removes only the fragment paths it created.

The shared C-byte BRE matcher compiles each expression once
and supports capture backreferences, byte classes and word assertions.
Repeated nullable captures follow the tested GNU candidate and capture-register
selection, including counted repeats and references. See the
[workspace support record](../../docs/compatibility.md#workspace-matcher-and-sed-candidates).
Existing output paths are refused. Locale-sensitive matching is outside the
selected profile. `--help` and `--version` provide command
information.

## Standalone metadata

Standalone `--version` prints exactly `csplit 0.2.1` followed by one
newline. Standalone `--help` starts with `Usage: csplit`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
