# rm

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Remove files, empty directories with `-d`, or directory trees with `-r`/`-R`.
Supports force (`-f`) and verbose (`-v`) modes. Recursive deletion never follows symbolic
links and refuses final dot/dot-dot operands. Windows accepts both slash and
backslash separators for this operand check; on POSIX a backslash remains part
of the filename. Root protection is on by default and follows
`--preserve-root` / `--no-preserve-root`; an explicitly named cwd
does not receive an extra repository policy. Operand failures do
not prevent later safe operands from being processed; the final status records
any failure. File access authorization belongs to the caller or host. Accepting
`--no-preserve-root` does not establish a tested root-deletion contract; that
destructive operation is not part of the validation fixtures.

The unpublished workspace candidate adds `-i` and bare
`--interactive`/`--interactive=always`, reading one response line from stdin
after each prompt on stderr. An affirmative starts with y/Y; leading spaces
are not trimmed, EOF declines, and a final unterminated response is accepted.
Recursive confirmation prompts before descending into nonempty directories,
then for each child and the final directory removal. A child refusal still
permits the later parent prompt and attempted removal, as GNU does.
Traversal uses an explicit stack and does not follow symbolic links.

`-I`/`--interactive=once` prompts once before inspection for recursive removal
or more than three original operands. Declining returns success and preserves
all operands. `-f` clears interaction and ignores missing files; selecting
always/once later restores missing-file diagnostics. `--interactive=never`
clears prompts while retaining the current ignore-missing state. The options
are applied in argument order. GNU no/none/yes aliases and unambiguous
prefixes are accepted. Explicit interaction works with piped stdin and does
not require a terminal or a separate `/dev/tty` channel.

Implicit terminal-sensitive write-protection prompting still needs a released
isatty API. Explicit prompts use real effective-write access for their labels;
permission bits are not fabricated. Published coordinates remain frozen.

## Standalone metadata

Standalone `--version` prints exactly `rm 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: rm`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
