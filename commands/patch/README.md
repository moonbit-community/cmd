# patch

Version **0.1.1** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Apply a checked unified or context diff:

```sh
moonx cli/diff -u --label old.txt --label new.txt old.txt new.txt | moonx cli/patch --dry-run
moonx cli/patch --dry-run -i change.diff
moonx cli/patch -o - -i change.diff original.txt
```

Unified (`---`/`+++`/`@@`) and traditional context (`***`/`---`/`********`)
patches are parsed into exact hunks. Context lines must match at the declared
position. File headers are parsed before writes, and each file's hunks are
checked before producing its output. `-R`
reverses additions and removals. `-pN` strips leading path components, `-d`
changes the base directory, `-i` selects the patch input, and `-o -` emits the
result to stdout. `--dry-run` performs the same checks without changing files.
`-s` suppresses routine progress; use it with `-o -` for clean content output.
`-u`/`-c` require unified/context input and `-t` accepts the noninteractive
profile. `-F0` is the only accepted fuzz setting. Without `-p`, only the
basename is retained; unsafe traversal paths after stripping are rejected.

Creating a file from `/dev/null` and deleting a file to `/dev/null` are
supported when the result is unambiguous. Updating an existing pathname is
deliberately rejected before reading the target: an in-place write could
modify hard-link aliases, while replacing the inode requires the original
file mode, which released MoonBit APIs do not expose. Named `-o` output is
also rejected because upstream copies source permissions to the output.
Use `--dry-run` or `-o -` for existing files. This is an exact-hunk subset:
on a mismatch the current file produces no output, no `.rej` file is created,
and later file patches continue. Binary, mode, rename, fuzz, offset, and
interactive patches are not implemented. Errors return 2 for a malformed or
unsupported request and 1 for a hunk mismatch.
`--help` prints usage and `--version` prints the command and package version.

## Standalone metadata

Standalone `--version` prints exactly `patch 0.1.1` followed by one
newline. Standalone `--help` starts with `Usage: patch`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
