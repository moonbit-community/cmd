# ln

Version **0.2.1** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Declining an interactive overwrite, including EOF, returns status 1 without
changing the destination; other operands are still processed.

Create symbolic links with `-s`, including force/interactive replacement
(`-f`/`-i`, last option wins), relative targets (`-r`), target directories (`-t`), explicit link
destinations (`-T`), backup controls (`-b`, `-S`), directory destinations, and
verbose output. `-n` only disables following a destination symlink; it is not
an alias for `-T`. Target-directory and replacement combinations are accepted
by the implementation but do not yet have complete differential coverage.

Hard links are unavailable through the public async 0.22.4 filesystem API on
both Native and Wasm, so `ln` without `-s` fails before mutation. Symbolic-link
creation is currently enabled on POSIX hosts only. These implementation limits
are separate from caller/host file-access authorization; see the
filesystem decision record in [ADR-0004](../../docs/adr/0004-filesystem.md).

The unreleased workspace adds standalone `--version`, which prints the command
name and package version and exits successfully without reading input.
Use `--help` to display usage.
