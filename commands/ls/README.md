# ls

Version **0.2.3** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

List files without invoking a host command. Supports hidden entries (`-a`,
`-A`), directory operands (`-d`), type indicators (`-F`, including executable
`*`), one-entry-per-line output (`-1`), recursion (`-R`), reverse order (`-r`),
time sorting (`-t`, selecting access/status time with `-u`/`-c` or `--time`),
regular-file size sorting (`-S`), and `-H/-L/-P` link-following selection. Ties
use C-locale byte order. `-u`, `-c` and `--time` imply time sorting unless an
explicit `-S` selects size sorting. The last `-S`/`-t` wins; the last time
selector wins independently. Multiple file operands are sorted too.
The C-profile hidden selection uses a leading dot: `-a` includes `.` and `..`,
while `-A` includes other dot names. Native Windows hidden attributes do not
replace this name rule.

`-C` lists down columns, `-x` across rows, `-m` uses comma-separated output,
and `-1` uses one name per line; the last format wins. `-w/--width` sets the
line width, with zero selecting an unlimited line. `-T/--tabsize` sets tab
stops, with zero disabling tabs. Explicit values override `COLUMNS` and
`TABSIZE`; invalid unoverridden environment values warn and retain defaults.
Layouts use each candidate column's maximum rendered name width, including
classification suffixes, rather than dividing by a global maximum. Tabs
replace at least two spaces. Effective color output disables tabs.

Names support GNU C-locale `literal`, `shell`, `shell-always`, `shell-escape`,
`shell-escape-always`, `c`, `c-maybe`, `escape`, `locale`, and `clocale`
quoting through `--quoting-style`. `-b` selects `escape`, `-N` selects
`literal`, and `-Q` selects `c`; explicit choices are last-wins and override
`QUOTING_STYLE`. Independently, `-q/--hide-control-chars` and
`--show-control-chars` select replacement of remaining nonprintable bytes
after quoting. In the fixed C profile, UTF-8 bytes are not printable:
literal `-q` displays one `?` per byte, while escape styles retain octal
escapes. Variable outer quotes align in finite-width column layouts.

`--color=always,never` explicitly controls `LS_COLORS`. Type, suffix,
case-sensitive extension exceptions, dangling links and `ln=target` use
released file-kind APIs. Color escapes retain their actual bytes. Repeated
definitions, normal/reset/end sequences and wrapping follow GNU coreutils
9.11. `never` ignores `LS_COLORS` entirely. With an empty `LS_COLORS`,
`TERM` and `COLORTERM` select whether the built-in palette is enabled;
automatic terminal detection remains unavailable.

The public filesystem API cannot read raw mode bits, capability xattrs or
link counts. Therefore a collection containing a regular file explicitly
rejects enabled `su`, `sg`, `ca`, `ex` or `mh` selectors; a directory rejects
enabled `tw`, `ow` or `st` selectors. Set the relevant selectors to `0`,
`00` or empty in `LS_COLORS` to use the remaining colors. This applies to
link targets when `ln=target` is selected. `can_execute` is effective access,
not a replacement for GNU's any-execute-mode-bit predicate. Exact mode-based
colors can be enabled once a released public metadata reader exposes these
fields. Long-format ownership, permissions and link counts remain outside
the profile; block and character **type colors** do use public `FileKind`.

When `-L` cannot dereference a directory entry, `ls` reports failure and still
prints that entry. With `-F`, a dangling symbolic link retains its `@` marker,
matching GNU coreutils 9.11.

`-H` follows command-line links; `-L` also follows links found in directories.
The last `-H/-L/-P` wins. With none of these options, command-line links to
directories are followed unless `-d` or `-F` is present. `-d` lists a directory
operand itself, even with `-R`; `-F` classifies the selected link or target.
Dangling links requested through `-H`/`-L` produce diagnostics: command-line
access failures exit 2; failures on entries within a readable directory exit 1
while retaining the names and other entries. `-P/--no-dereference` is a project
extension (GNU ls 9.11 does not accept `-P`).
Long listing, ownership, permissions, inode/link counts and blocks remain
outside the portable profile. `-S` rejects a set containing a
non-regular entry before listing it. Sorting multiple directory operands by
size is also rejected because public directory size metadata is unavailable.

The byte-order implementation
does not rewrite locale environment variables; file-access authorization
belongs to the caller or host.

## Standalone metadata

Standalone `--version` prints exactly `ls 0.2.3` followed by one
newline. Standalone `--help` starts with `Usage: ls`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
