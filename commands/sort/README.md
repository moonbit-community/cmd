# sort for moonx

Version **0.2.1** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Sort lines of files or stdin:

```sh
moonx cli/sort names.txt
printf '10\n2\n' | moonx cli/sort -n
moonx cli/sort -t, -k 2 -u data.csv
```

Options include `-r`, `-u`, `-b`, `-d`, `-f`, and `-i`, plus `-n` numeric,
`-g` general numeric, `-h` human numeric, `-M` month, and `-V` version
comparisons. Repeated `-k F[.C][OPTS][,F[.C][OPTS]]` keys support field,
character, and local comparison modifiers; `-t BYTE` selects a field
separator. `-z` selects NUL records. `-c/--check` diagnoses the first disorder
and `-C/--check=quiet` only returns status 1.

Comparison uses C-locale byte rules without changing environment variables.
Blank-separated fields retain their leading separator run unless `-b` applies;
case folding maps lowercase ASCII to uppercase, and human numeric order compares
sign, suffix magnitude, then numeric value. Key ties use the whole record as the
last resort and remaining ties retain input order. `-R` is recognized but
rejected before reading input because the package has no audited deterministic
seed contract.

The implementation remains bounded to in-process sorting and never creates
temporary files. With no file operand, it silently reads stdin until EOF.

## Standalone metadata

Standalone `--version` prints exactly `sort 0.2.1` followed by one
newline. Standalone `--help` starts with `Usage: sort`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
