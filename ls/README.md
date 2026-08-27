# ls

List files without invoking a host command. Supports hidden entries (`-a`,
`-A`), directory operands (`-d`), type indicators (`-F`), one-entry-per-line
output (`-1`, the deterministic default), and recursion (`-R`). Long listing
is intentionally excluded because Moonrun does not expose portable ownership
and permission metadata on every supported target.
