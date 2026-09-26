# mktemp

`mktemp` creates a unique temporary pathname and atomically reserves it.

```text
moonx cli/mktemp -d /tmp/moonx.XXXXXX
moonx cli/mktemp /tmp/moonx.XXXXXX
```

The implemented subset supports one template operand and `-d`/`--directory`.
The template must end in at least three `X` characters. A file is created with
mode `0600`; a directory is created with mode `0700`. The command uses the
released MoonBit entropy API and `CreateNew`/`mkdir`, retrying collisions up to
100 times. Unsupported GNU options are rejected before any path is created.

The default template is `$TMPDIR/tmp.XXXXXX`, falling back to `/tmp/tmp.XXXXXX`.
Platform-specific template and permission behavior remains subject to the
public async filesystem API and is covered by the command compatibility record.
