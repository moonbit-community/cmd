# mktemp

Version **0.1.3** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Create one unique temporary file, or a directory with `-d`/`--directory`:

```sh
moonx cli/mktemp /tmp/moonx.XXXXXX
moonx cli/mktemp -d /tmp/moonx.XXXXXX
```

The template ends in at least three `X` characters. Names use the released
MoonBit random source and exclusive creation, so collisions are retried before
failure; files use mode 0600 and directories 0700. Template extensions,
owner metadata and platform-specific mode details are not claimed.

## Standalone metadata

Standalone `--version` prints exactly `mktemp 0.1.3` followed by one
newline. Standalone `--help` starts with `Usage: mktemp`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
