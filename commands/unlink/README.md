# unlink

Version **0.1.2**. See the [support record](../../docs/compatibility.md) for release evidence.

Remove exactly one non-directory name:

```sh
moonx cli/unlink temporary.txt
```

Missing or extra operands fail before anything is removed. A symbolic
link is removed without following its target. Directories are rejected;
filesystem errors return status 1. `--help` and `--version` are available.
