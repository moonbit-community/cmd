# unlink

Version **0.1.1** behavior is documented here. The
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

Multiple operands are a project extension: GNU unlink accepts one operand and
rejects extras before removing anything. This difference is tracked for a
future command-fidelity correction in the [follow-up record](../../docs/command-followups.md).
