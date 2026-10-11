# which

Version **0.1.0** is a local candidate. See the
[support record](../../docs/compatibility.md) for verification and release status.

Resolve command names against the caller's `PATH`:

```sh
moonx cli/which sh
moonx cli/which -a sh
```

`-a`/`--all` prints every matching regular file, and `-s`/`--silent` suppresses
output while retaining the status. An operand containing a path separator is
checked directly. The public MoonBit filesystem API does not expose portable
executable-mode inspection, so this profile verifies regular-file presence and
does not claim shell aliases, functions, or full platform executable-bit
semantics.
