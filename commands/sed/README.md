# sed

Version **0.1.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Edit byte-oriented text streams with `p`, `d`, `q`, `=`, and substitution
`s/REGEXP/REPLACEMENT/`. Read stdin when no input file is given or an operand
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

In-place editing, hold space, branches, command groups, multiline commands,
pattern backreferences, word assertions and locale-aware matching are not
included. Unsupported syntax is rejected before input is processed.
`--help` and `--version` are available. Exit status is 0 on success, 1 for an
invalid script or evaluation error, and 2 for an unreadable input file.
