# sed

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Edit byte-oriented text streams with `p`, `d`, `q`, `=`, and substitution
`s/REGEXP/REPLACEMENT/`. Hold-space commands `h/H/g/G/x`, labels and branches
`:/b/t/T`, nested addressed groups, and `n/N/P/D/a/i/c` are available in the
unpublished workspace candidate. Read stdin when no input file is given or an operand
is `-`. Multiple input files share line numbering, address ranges and the
last-line address `$`.

```sh
moonx cli/sed 's/old/new/g' file.txt
moonx cli/sed -n '2,5p' file.txt
moonx cli/sed -E 's/([0-9]+)/[\1]/g' file.txt
```

`-n/--quiet/--silent` suppresses automatic output. Use repeated `-e/--expression`
and `-f/--file` options to combine scripts in order. `-E` or `-r` selects extended
regular expressions; basic expressions are the default. A first-line `#n`
comment also disables automatic output.

Addresses accept positive line numbers, `$`, `/REGEXP/`, two-address ranges
and `!` inversion. Substitution supports `&`, replacement captures `\1` through
`\9`, `g`, a positive occurrence number, and `p`. An empty expression reuses
the last executed regular expression. Unterminated input records retain their
missing final newline; later output inserts the required record separator.

Pattern and hold spaces retain their final-newline state. Branches use the last
definition of a label; `t/T` consume substitution success, and a new input read
resets it. `D` restarts without reading. Appended text is deferred to the input
cycle boundary; inserted text is immediate. Multiple files share these states.
Scripts compile before input is opened, including label and group resolution.

The shared C-byte BRE/ERE matcher supports pattern backreferences, byte classes
and word assertions. Backreferences to nullable captures cloned by repetition
are rejected before input processing; ordinary references and non-cloned star
paths remain supported. See the [workspace support record](../../docs/compatibility.md#workspace-matcher-and-sed-candidates).
In-place editing and locale-aware matching remain outside this profile.
Unsupported syntax is rejected before input is processed.
`--help` and `--version` are available. Exit status is 0 on success, 1 for an
invalid script or evaluation error, 2 for an unreadable input file, and 4 for a
missing branch label. Diagnostics follow the project's format rather than GNU's
script-position wording. Pattern/hold growth and branch termination are controlled
by the script; no hidden execution-step limit is imposed.

## Standalone metadata

Standalone `--version` prints exactly `sed 0.2.0` followed by one
newline. Standalone `--help` starts with `Usage: sed`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
