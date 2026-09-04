# jq for moonx

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Run jq-compatible JSON filters without installing a separate binary:

```sh
printf '%s' '{"name":"Moon"}' | moonx cli/jq -r '.name'
moonx cli/jq -n -c '{ok: true, values: [1, 2]}'
moonx cli/jq -c '.items[]' data.json
```

`moonx` uses the linear-memory WebAssembly build by default. Arguments after
`cli/jq` are passed directly to the jq-compatible command.

Supported options:

- `-c`, `--compact-output`: print compact JSON.
- `-r`, `--raw-output`: print strings without JSON quotes.
- `-f`, `--from-file FILE`: read the filter from `FILE`.
- `-n`, `--null-input`: evaluate once with `null` input.
- `-l`, `--logs`: process newline-delimited JSON and skip invalid lines.
- `-S`, `--sort-keys`: recursively sort object keys for deterministic output.
- `-j`, `--join-output`: omit separators between filter results.
- `-s`, `--slurp`: evaluate one array containing all input values.
- `-R`, `--raw-input`: treat each input line as a JSON string.
- `-e`, `--exit-status`: return 1 for false/null and 4 when no result is produced.
- `--arg NAME VALUE`, `--argjson NAME JSON`: bind literal values for `$NAME`.
- `--indent N` and `--tab`: select deterministic pretty-print indentation.

The evaluator is the imported MoonJQ implementation. Its map, reduce,
assignment, and try/catch slices are usable through this CLI; modules,
streaming, and every jq 1.8.2 diagnostic are not claimed.
