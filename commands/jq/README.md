# jq

Filter JSON for MoonX.

```sh
moonx cli/jq@0.2.4 [OPTION]... [FILTER] [FILE...]
```

## Supported scope

Apply jq-compatible filters to consecutive JSON values, files or stdin. Supports maps, reduce, assignments, try/catch, variables and Unicode string slices. No filter selects identity.

## Options

| Option | Description |
| --- | --- |
| `-c, --compact-output` | print compact JSON |
| `-r, --raw-output` | print strings without JSON quotes |
| `-j, --join-output` | raw output without result separators |
| `-n, --null-input` | evaluate once with null; do not read inputs |
| `-s, --slurp` | collect input values in an array |
| `-R, --raw-input` | read text lines; -Rs reads all text |
| `-l, --logs` | skip non-JSON lines (project extension) |
| `-S, --sort-keys` | sort object keys recursively |
| `-e, --exit-status` | return 1 for false/null, 4 for no result |
| `-f, --from-file FILE` | read the filter from FILE |
| `--arg NAME VALUE` | bind a string variable |
| `--argjson NAME JSON` | bind a JSON variable |
| `--indent N` | indentation -1 (tabs) through 7 |
| `--tab` | indent with tabs |
| `-C, --color-output` | emit ANSI colors (JQ_COLORS customizes the palette) |
| `-M, --monochrome-output` | disable colors, including when -C is present |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Modules, --stream events and full jq compatibility are unsupported.
- Color requires explicit -C; automatic terminal color is unavailable. -l/--logs skips invalid lines and conflicts with -n/-R.

## Examples

```sh
printf '%s' '{"name":"Moon"}' | moonx cli/jq@0.2.4 -r '.name'
moonx cli/jq@0.2.4 -n -c '{ok: true, values: [1, 2]}'
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0007-language.md)
