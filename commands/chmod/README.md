# chmod

This documents version 0.2.0. The [support record](../../docs/compatibility.md)
tracks platform verification and exact-version publication evidence separately.

Change Unix-style permission bits through the public MoonBit filesystem API
on POSIX hosts. Supports octal modes, `-R`/`--recursive`, and `-v`/`--verbose`.
Numeric modes follow symbolic links named as command-line operands and change
their targets. Links encountered while walking a real directory with `-R` are
skipped. Recursive traversal through a command-line directory symlink is not
implemented: only that target's own mode is changed.

Closed symbolic assignments such as `a=rwx` or `u=rw,g=r,o=` are supported for
regular files. They must explicitly assign all of `u`, `g`, and `o`; operands
are checked for this subset before mutation. Incremental `+/-`, omitted
classes, `X/s/t`, permission copies, directories and symlinks remain rejected
for symbolic assignments. Numeric operations process operands in order and do
not roll back earlier successful changes on a later error.

`--reference` is recognized but fails before mutation because async 0.22.4
does not expose current permission bits. Windows permission mutation is
unavailable in this profile. Host permission denial is reported separately
from these implementation limits.
