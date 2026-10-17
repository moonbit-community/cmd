# unlink

Version **0.1.3**. See the [support record](../../docs/compatibility.md) for release evidence.

Remove exactly one non-directory name:

```sh
moonx cli/unlink temporary.txt
```

Missing or extra operands fail before anything is removed. A symbolic
link is removed without following its target. Directories are rejected;
filesystem errors return status 1. `--help` and `--version` are available.

## Standalone metadata

Standalone `--version` prints exactly `unlink 0.1.3` followed by one
newline. Standalone `--help` starts with `Usage: unlink`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
