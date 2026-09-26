# tree

Version **0.1.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Display a sorted recursive directory tree:

```sh
moonx cli/tree .
moonx cli/tree -L 2 --noreport project/
```

The verified profile supports `-a`/`--all`, `-d`/`--dirs-only`,
`-f`/`--full-path`, `-L`/`--level`, and `--noreport`, with one or more roots.
Symbolic-link entries are rejected explicitly because the released public
filesystem API does not expose link targets. Color, ownership, permissions,
device metadata and extended reports are outside this profile.
