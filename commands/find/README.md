# find

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Walk directory trees without following symbolic links. Supports `-name` and
`-path` shell patterns, `-type`, `-xtype`, `-empty`, `-size`, `-amin/-atime`,
`-cmin/-ctime`, `-mmin/-mtime`, `-newer`, `-anewer`, `-cnewer`, `-newerXY`,
`-used`, `-readable/-writable/-executable`, depth limits, `-depth`, `-prune`,
negation, AND/OR composition, and newline or NUL output. `-exec COMMAND ... ;` runs one direct child per match, while
`-exec COMMAND ... +` batches paths in deterministic traversal order under a
64 KiB argument budget. `-delete` removes matching files and empty directories
in postorder. Only one output/execution action is accepted, and `-exec` must
be the final expression action. In `-newerXY`, X and Y are limited to `a`,
`c`, or `m`; birth-time and literal-time selectors are not implemented.

The caller or host grants file reads, mutation for `-delete`, and process
launches for `-exec`. Child commands inherit the complete caller environment,
including locale variables. The command adds no authorization allowlist.
Actions are parsed before traversal and
unsupported expressions fail without side effects. The profile does not follow
symlinks or claim ownership/link-target predicates or the full findutils
expression language. Time references are read once before traversal and all
entries share one fixed current-time sample.

Time/reference/access combinations and special-file predicates remain
partially verified; option acceptance is not a claim of complete findutils
compatibility.
