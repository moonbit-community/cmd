# patch

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Apply a checked unified or context diff:

```sh
moonx cli/diff -u --label old.txt --label new.txt old.txt new.txt | moonx cli/patch --dry-run
moonx cli/patch --dry-run -i change.diff
moonx cli/patch -o - -i change.diff original.txt
```

Unified (`---`/`+++`/`@@`) and traditional context (`***`/`---`/`********`)
patches are parsed before writes. Hunks first search for all context at the
declared position plus the previous successful offset. Other candidates are
tried by increasing distance, with a later candidate winning an equal-distance
tie. If no exact-context candidate matches, fuzz removes outer context in
successive tiers; `-F/--fuzz=N` sets the maximum (default 2, `-F0` keeps all
context). Unequal leading/trailing context retains GNU's start/end anchoring.
Ignored context is copied from the actual input, preserving its bytes. `-R`
reverses additions and removals. `-pN` strips leading path components, `-d`
changes the base directory, `-i` selects the patch input, and `-o -` emits the
results to stdout in file-patch order. An explicit ORIGINALFILE still requires
a single-file patch. With `-o -`, progress and hunk diagnostics go to stderr.
`--dry-run` performs the same checks without creating targets, rejects or
temporary files; an explicit `-o -` still emits the checked result.
`-s` suppresses routine progress and individual hunk messages, but retains the
failed-hunk summary.
`-u`/`-c` require unified/context input. `-t/--batch` checks the first hunk in
both directions at each fuzz tier and automatically selects a detected reverse,
including a create/delete whose expected existence is reversed. It reports the
choice without reading confirmation from patch stdin. Without `-p`, only the
basename is retained; unsafe traversal paths after stripping are rejected.

Creating a file from `/dev/null` and deleting a file to `/dev/null` are
supported when the result is unambiguous. Updating an existing pathname is
deliberately rejected before reading the target: an in-place write could
modify hard-link aliases, while replacing the inode requires the original
file mode, which released MoonBit APIs do not expose. Named `-o` output is
also rejected because upstream copies source permissions to the output.
Use `--dry-run` or `-o -` for existing files.

A rejected hunk leaves its input region unchanged and does not prevent later
hunks or files from being checked and applied. Successfully applied hunks retain
their effects in the result. Rejected hunks preserve their unified/context
format, original header text, section, no-newline markers and order; their
ranges account for earlier successful changes. New rejects default to
`<output>.rej` (`-.rej` with `-o -`). `-r/--reject-file=FILE` selects one new
reject file shared by the invocation, and `-r -` discards reject data. Reject
files are exclusively created and remain open while appending this invocation's
later rejects. Existing reject destinations are refused before target writes;
they are never truncated or followed as a replacement workaround.

A partially applied deletion that would rewrite remaining existing content
has the same mode-preservation boundary as an ordinary existing-file update.
An entirely rejected deletion leaves a nonempty target unchanged; deletion of
an already-empty target follows the selected GNU empty-output behavior. A fully
successful deletion removes its target. Binary, mode, rename and interactive reversal prompting
remain outside this profile. Errors return 2 for a malformed, unsupported or
fatal filesystem request, 1 when any hunk is rejected, and 0 when all apply.
Inputs and patches are still buffered; offset/fuzz support does not establish
a constant-memory claim.
`--help` prints usage and `--version` prints the command and package version.

## Standalone metadata

Standalone `--version` prints exactly `patch 0.2.0` followed by one
newline. Standalone `--help` starts with `Usage: patch`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
