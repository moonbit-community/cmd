# ls

Version **0.2.0** behavior is documented here. The
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
Long listing, ownership, permissions, inode/link counts, blocks, and full color
rules remain outside the portable profile. `-S` rejects a set containing a
non-regular entry before listing it. Sorting multiple directory operands by
size is also rejected because public directory size metadata is unavailable.

The byte-order implementation
does not rewrite locale environment variables; file-access authorization
belongs to the caller or host.
