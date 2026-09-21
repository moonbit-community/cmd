# mkdir

This documents version 0.2.0. The [support record](../../docs/compatibility.md)
tracks platform verification and exact-version publication evidence separately.

Create one or more directories. Supports recursive parent creation (`-p`),
numeric octal modes (`-m`), and verbose output (`-v`). Failed operands do not
stop later directories from being attempted.

Without `-m`, new directories use `0777 & ~umask`. With `-p -m MODE`, only the
requested leaf receives MODE; newly created parents use the default mode.
Existing directories accepted by `-p` keep their permissions. Numeric `-m`
is applied after creation so the requested leaf mode is not reduced by umask.
Symbolic modes are not implemented. The parent-permission behavior is verified
under ordinary POSIX umasks; unusual umasks requiring temporary owner
write/search permissions and Windows mode semantics remain unverified.
