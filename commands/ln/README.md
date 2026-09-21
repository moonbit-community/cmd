# ln

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Create symbolic links with `-s`, including force/interactive replacement
(`-f`/`-i`), relative targets (`-r`), target directories (`-t`), explicit link
destinations (`-T`), backup controls (`-b`, `-S`), directory destinations, and
verbose output. `-n` only disables following a destination symlink; it is not
an alias for `-T`. Target-directory and replacement combinations are accepted
by the implementation but do not yet have complete differential coverage.

Hard links are unavailable through the public async 0.22.1 filesystem API on
both Native and Wasm, so `ln` without `-s` fails before mutation. Symbolic-link
creation is currently enabled on POSIX hosts only. These implementation limits
are separate from caller/host file-access authorization; see the
[upstream gap record](../../docs/async-upstream-gaps.md).
