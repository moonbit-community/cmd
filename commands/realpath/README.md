# realpath

Version **0.1.3** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Print canonical paths for one or more operands:

```sh
moonx cli/realpath -e input.txt
moonx cli/realpath -z input.txt other.txt
```

`-e`/`--canonicalize-existing` requires every component to exist, and
`-z`/`--zero` terminates records with NUL bytes. Operands are handled
independently; a failed operand does not erase earlier output.

The unpublished workspace candidate defaults to allowing a missing final
component (`-E/--canonicalize`), while `-e` requires every component.
`-m/--canonicalize-missing` also permits missing and non-directory components.
`-s/--strip/--no-symlinks` suppresses link expansion; only `-ms` is fully
lexical. Bare `-s` still checks existence and intermediate directories.
Physical modes walk components and expand resolvable links with the public
filesystem API, so `link/..` follows the actual target before traversing up.
Missing ordinary paths are supported without a blanket physical-mode rejection.

`--relative-to=DIR` computes relative output after canonicalization.
`--relative-base=DIR` limits relative output to descendants and defaults the
reference directory to the same base. Component boundaries are respected;
if the reference is outside the base, all operands remain absolute. Existing
mode requires the reference/base to be directories. `-q/--quiet` suppresses
operand failures, preserving failure status and successful output; invalid
reference initialization and usage errors remain visible.

An identified symbolic link that public `fs.realpath` cannot expand is a
narrow boundary when missing-mode resolution needs its target text. No public
readlink API is available, so those cases fail with an explicit diagnostic
and status 2 rather than pretending the link is an ordinary lexical component.
`-ms` can handle the same spelling lexically. Published coordinates remain frozen.
`--help` prints usage and `--version` prints the command and package version.

## Standalone metadata

Standalone `--version` prints exactly `realpath 0.1.3` followed by one
newline. Standalone `--help` starts with `Usage: realpath`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
