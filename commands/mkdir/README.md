# mkdir

This documents version 0.2.2. The [support record](../../docs/compatibility.md)
tracks platform verification and exact-version publication evidence separately.

Create one or more directories. Supports recursive parent creation (`-p`),
numeric octal modes (`-m`), and verbose output (`-v`). Failed operands do not
stop later directories from being attempted.

Without `-m`, new directories use `0777 & ~umask`. With `-p -m MODE`, only the
requested leaf receives MODE; newly created parents use the default mode.
Existing directories accepted by `-p` keep their permissions. Numeric `-m`
is applied after creation so the requested leaf mode is not reduced by umask.
The unpublished workspace candidate adds symbolic modes evaluated from 0777:
explicit u/g/o/a classes, `+/-/=`, rwx/X, setuid/setgid/sticky bits, sequential
copied classes and comma clauses. X applies because the target is a directory.
Omitted-who expressions are accepted when their final result is provably
independent of all POSIX umasks, including `+w` and later explicit overrides.
Expressions whose final value requires the unavailable process umask fail
before creation with status 2 and an explicit capability diagnostic. No umask
is guessed from environment, effective access or probe-file permissions.

Parent creation retains its ordinary POSIX behavior. Exact GNU owner
write/search additions under restrictive umasks, preservation of inherited
directory special bits, and Windows permission-bit semantics require actual
umask/permission observation unavailable in the released portable APIs.
New symbolic leaves explicitly reject platforms where the portable permission
setter is unavailable; existing directories accepted by -p need no setter.
Calculated symbolic modes and real per-platform setter effects are separate
claims. Frozen published coordinates remain unchanged.

## Standalone metadata

Standalone `--version` prints exactly `mkdir 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: mkdir`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
