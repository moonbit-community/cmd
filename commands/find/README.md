# find

Development candidate: `cli/find@0.2.6`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Search directory trees for MoonX.

```sh
moonx cli/find@0.2.6 [PATH...] [EXPRESSION]
```

## Supported scope

Walk with the default no-follow profile. Combine predicates with negation, AND
and OR; actions execute at their position in that expression. On POSIX, a
trailing slash requires a directory, including through a directory link.

Directory names are read only when descending or evaluating `-empty`; a
short-circuited `-empty`, `-prune`, or the maximum-depth boundary does not itself
enumerate children. Each evaluated `-empty` reads directory names; descent can
reuse those names. Required stat fields are captured before directory reads,
actions and descendant effects, and survive postorder traversal or deletion.
Access checks and followed-link queries remain live operations.
`-exec ... +` executes completed batches during traversal and accounts for UTF-8
argument bytes, including repeated placeholders, within a 64 KiB payload budget.

`-size` compares the ceiling of the entry's byte size divided by its unit:
default/`b` = 512, `c` = 1, `w` = 2, `k` = 1024, `M` = 1048576 and
`G` = 1073741824. Thresholds use unsigned 64-bit integers. Uppercase `K` is
a retained project extension. Size is no-follow metadata; unreadable files,
links and special files are never opened to measure them. `-empty` accepts only
an empty regular file or directory.

Time arguments accept finite decimal, exponent and hexadecimal binary64
numbers. Day and minute predicates use GNU 4.10.0's different window origins;
an exact window excludes its lower endpoint and includes its upper endpoint.
`-used` rejects access times older than status-change times. `newerXY` compares
the selected a/c/m fields, including no-follow reference-link timestamps.
The startup wall clock has millisecond precision; file timestamp nanoseconds
are retained. Nonfinite values and conversions outside signed 64-bit seconds
are explicitly rejected instead of reproducing undefined C conversions.

`-xtype` follows a link and falls back to the link's type for a missing,
non-directory or looping target. Other target lookup errors set failure even
when negation makes the predicate match. A missing starting path fails even
when its expression would short-circuit. A single `-exec ... ;` child failure
is a false predicate; failed grouped execution also makes find fail.

## Options

| Option | Description |
| --- | --- |
| `-name PATTERN / -path PATTERN` | Match names / paths with shell patterns. |
| `-type / -xtype / -empty / -size` | Test entry type, emptiness or size. |
| `-amin / -atime / -cmin / -ctime / -mmin / -mtime` | Test access, status-change or modification age. |
| `-newer / -anewer / -cnewer / -newerXY / -used` | Compare timestamps; X/Y support a, c and m. |
| `-readable / -writable / -executable` | Query the public filesystem access checks. |
| `-mindepth / -maxdepth / -depth / -prune` | Control traversal. |
| `-print / -print0` | Print newline / NUL-delimited paths. |
| `-exec COMMAND ... ; / +` | Execute per match / in batches. |
| `-delete` | Delete matches in postorder. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Symlink following, ownership/link-target predicates and the complete findutils language are unsupported.
- Only one output/execution action is accepted; -exec must be the final expression action. Birth-time and literal-time selectors are unsupported.
- Combining `-prune` and `-delete` requires explicit `-depth`, since postorder traversal makes pruning ineffective. Only the literal starting path `.` is protected as a successful deletion no-op.
- Unavailable size or timestamp metadata produces status 1 when its predicate is evaluated. In particular, the current macOS public API cannot supply directory size. It is never replaced by zero or a successful nonmatch.
- Access checks do not establish raw permission bits, ACL equivalence or behavior with differing real and effective identities. Complete findutils grammar and diagnostic-byte parity are outside this profile.

## Examples

```sh
moonx cli/find@0.2.6 . -name '*.mbt'
moonx cli/find@0.2.6 . -type f -maxdepth 2 -print0
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
