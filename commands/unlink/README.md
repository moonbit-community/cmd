# unlink

Version **0.1.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Remove one or more regular-file or symbolic-link operands in order:

```sh
moonx cli/unlink temporary.txt
```

A later failure does not undo earlier removals. Directories are rejected, and
the operation never follows a link to inspect its target. `--help` and
`--version` are available; owner metadata and every diagnostic byte are not
claimed.
