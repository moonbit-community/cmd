# diff

Version **0.2.1** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Compare two files or directories, using `-` for stdin. Normal output identifies
inserted, deleted and changed lines; `-u/-U` selects unified output and
`-c/-C` selects context output, with three context lines by default.

```sh
moonx cli/diff old.txt new.txt
moonx cli/diff -u --label old --label new old.txt new.txt
```

`-q/--brief` reports differences without a patch. `-s/--report-identical-files`
reports equal files. `-a/--text` treats NUL-containing inputs as text, preserving
NUL and malformed UTF-8 bytes. Repeated `--label` options set the displayed
left and right names, including brief, identical and binary reports.

`-i/--ignore-case` compares ASCII letters without case. `-w/--ignore-all-space`
ignores C whitespace within each line; `-b/--ignore-space-change` collapses
whitespace runs and ignores trailing whitespace. `-Z/--ignore-trailing-space`
ignores trailing whitespace only. Those whitespace modes also ignore the
missing final line-feed distinction. `-B/--ignore-blank-lines` suppresses a
change group only when every changed line is blank under the selected comparison
rules; it does not remove blank lines before comparison. Unified/context hunks
containing another substantive change retain the blank changes.

`--strip-trailing-cr` removes one CR immediately before each LF, including
displayed lines; a CR in an unterminated final line remains. Other comparison
transformations preserve the original displayed bytes. Input records are byte
views into the two buffered files. Comparison classes reuse those views when
possible; only transformed keys allocate additional bytes. Rendering converts
displayed records to text without converting either complete input file.

Directory entries are processed in C byte order. Without `-r/--recursive`, common
subdirectories are reported without descent. `-N/--new-file` compares missing
sides as empty; `--unidirectional-new-file` does so only for a missing left side.
A file paired with a directory selects the corresponding basename in that
directory. Recursive traversal uses public path resolution to detect ancestor
loops. Directory/file type differences and directory FIFO/socket pairs are
reported like the fixed GNU profile. Top-level readable special files are
compared as input streams. Directory character/block device pairs require
device-number metadata; the same resolved path is equal, while other pairs
remain an explicit device-number capability boundary.
Symlinks follow their public filesystem targets; comparing link-target text
itself remains outside this profile.
Path messages use C-locale shell escaping, while automatic unified/context
header names use C quoting. Explicit `--label` text remains unchanged.

Exit status is 0 for identical files, 1 for a difference, and 2 for an input
or option error. Directory errors retain earlier output and do not hide errors
behind later successful entries. Non-C locale collation is outside this release.
Timestamp headers honor `TZ`, `TZDIR`,
64-bit TZif transitions and explicit POSIX DST rules, including dates after
2038. With no `TZ`, the host's `/etc/localtime` is used. Missing timezone
data is an error. Unified output uses ISO timestamps and context output uses the
traditional weekday/month/day format. Use `--label` for stdin or hosts without
a timezone database. `--help` and `--version` are available.
Both files, record indexes, distinct comparison keys and patch output remain
buffered. Unchanged keys share input bytes. Edit reconstruction uses
bidirectional Myers frontiers and an explicit partition stack with O(N+M)
auxiliary space, excluding input/key bytes and the produced edit/output records.
Records without a possible counterpart bypass the edit search. Equivalent-line
change alignment joins neighboring changes and exercises the registered GNU
repeated-line cases. This is neither constant-memory diff nor a linear-time
guarantee for high edit density.

## Standalone metadata

Standalone `--version` prints exactly `diff 0.2.1` followed by one
newline. Standalone `--help` starts with `Usage: diff`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
