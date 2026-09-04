# sort for moonx

Observed native/Wasm profile (2026-09-04): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable unified-runner results and exclusions.

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

The deterministic profile compares transformed bytes under `LC_ALL=C`.
Blank-separated fields retain their leading separator run unless `-b` applies;
case folding maps lowercase ASCII to uppercase, and human numeric order compares
sign, suffix magnitude, then numeric value. Key ties use the whole record as the
last resort and remaining ties retain input order. `-R` is recognized but
rejected before reading input because the package has no audited deterministic
seed contract.

The implementation remains bounded to in-process sorting and never creates
temporary files. With no file operand, it silently reads stdin until EOF.
