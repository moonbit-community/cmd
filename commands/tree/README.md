# tree

Version **0.1.3** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Display a sorted recursive directory tree:

```sh
moonx cli/tree .
moonx cli/tree -L 2 --noreport project/
```

The C-locale profile supports `-a`/`--all`, `-d`/`--dirs-only`,
`-f`/`--full-path`, positive `-L`/`--level`, and `--noreport`, with one or more
roots. Text uses ASCII branches and C byte ordering. Names escape spaces,
backslashes, control bytes and non-ASCII bytes. Directory totals include
nonempty roots, matching the fixed tree 2.2.1 provider; an empty root itself
does not contribute to its report. `-d` omits the file total.

`-P` includes file patterns, `-I` excludes names and matching directory
subtrees, and repeated patterns form unions. Patterns support `*`, `**`, `?`,
bracket sets/ranges with `^` negation, backslash escapes and `|` alternatives.
`--ignore-case` folds ASCII C-locale bytes. `--matchdirs` allows a matching
directory's immediate contents; nested matches use their relative path.
`--prune` removes empty selected branches, retaining directories that match
`--matchdirs`. `--filelimit N` counts selected entries before descent; positive
limits annotate a directory instead of traversing it, while zero/negative
values disable the limit. Prune, depth and filelimit order follows the fixed
provider, including its report behavior after pruning all descendants.

`-J` emits JSON with escaped names, nested contents and an optional report
entry. `-H BASE` emits HTML with links; `-T TITLE` selects its title. The last
`-J` or `-H` wins. `--noreport` also removes structured reports. JSON never
contains ANSI colors. HTML escapes title, base and names, encodes URL path
bytes, declares UTF-8, and identifies the real `cli/tree` version. These are
explicit product contracts: the upstream 2.2.1 unsafe title/path insertion,
generator banner, stylesheet and credits are not reproduced as whole-page parity claims.

Traversal and pruning use a private visit/finish stack; counting and all three
renderers are iterative. The necessary selected nodes are retained for prune
and structured output. Text, JSON and HTML flush bounded output batches rather
than building a second copy of the complete rendered listing.

`-C` forces explicit `TREE_COLORS` type/extension colors, falling back to
`LS_COLORS`. `-n` disables unforced color; like the provider, an explicit `-C`
takes precedence in either order. No new terminal auto-detection is added.
`TERM` must be present for text colors. Suffix definitions are case-sensitive
and last matching definitions win. Types include directories, regular files,
FIFO/socket and block/character devices through public `FileKind`.

The public API cannot read raw mode bits. Text colors therefore reject
present `su`, `sg`, `ex` selectors for regular files and `tw`, `ow`, `st`
selectors for directories. Omit those definitions to use the remaining
colors; unlike GNU ls, tree treats even `ex=0` as an enabled predicate. The
built-in regular-file palette includes `ex`, so it also needs the missing
reader. HTML `-C` requires executable classification for regular files and
explicitly rejects that combination until raw mode bits become public.
Effective access is never substituted for the any-execute-mode-bit test.

`-s`, `-h`, `--si` and `--du` read actual public size metadata, including
the fixed provider's float32 human-size rounding. `--du` sums each selected
directory's own size and its selected descendants in postorder. The released
Linux backend exposes directory inode sizes through `file_size`; macOS Native
and Wasm currently report `Operation not supported` for directories. Such
metadata errors are reported rather than replaced by an invented size.
Unavailable mode categories can be enabled after a released public metadata
reader and corresponding platform/provider revalidation.

Symbolic-link entries selected for display remain explicitly rejected because
the public filesystem API does not expose the target text needed by tree.
Ownership, permissions and inode/device-number reports remain outside this
profile. Existing access failures retain explicit command diagnostics rather
than reproducing the upstream missing-root malformed JSON output.
`--help` prints usage and `--version` prints the command and package version.

## Standalone metadata

Standalone `--version` prints exactly `tree 0.1.3` followed by one
newline. Standalone `--help` starts with `Usage: tree`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
