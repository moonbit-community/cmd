# mktemp

Version **0.1.3** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Create one unique temporary file, or a directory with `-d`/`--directory`:

```sh
moonx cli/mktemp /tmp/moonx.XXXXXX
moonx cli/mktemp -d /tmp/moonx.XXXXXX
```

Names use the released MoonBit random source and exclusive creation, so
collisions are retried before failure; files request mode 0600 and directories
0700, subject to the operating system umask. Owner metadata and Windows
permission-bit semantics are not claimed.

The unpublished workspace candidate parses the template once. The final run
of X characters must contain at least three, and may precede an inferred
suffix (`name.XXX.log`). `--suffix=TEXT` instead requires the original template
to end in X. A suffix cannot contain a directory separator. Generated names
use uniformly selected ASCII letters and digits. Exclusive-create collisions
are retried up to 238328 times; failed attempts never overwrite an existing entry.

No operand selects `tmp.XXXXXXXXXX` under nonempty TMPDIR, then `/tmp`.
An explicit template stays relative to cwd unless a destination option is used.
`-p DIR`/`--tmpdir[=DIR]` selects a nonempty directory argument before TMPDIR
and `/tmp`, permits existing relative subdirectories and rejects absolute
templates. `-t` always prefers TMPDIR, then `-p`, then `/tmp`, and rejects
directory components in the template. Bare `--tmpdir` does not consume the
next operand. `-q/--quiet` suppresses creation/output errors while preserving
template and usage diagnostics. If printing a created name fails, removal of
that new entry is attempted. Unsafe dry-run `-u` is not supported. Frozen releases are unchanged.

## Standalone metadata

Standalone `--version` prints exactly `mktemp 0.1.3` followed by one
newline. Standalone `--help` starts with `Usage: mktemp`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
