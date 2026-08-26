# jq for moonx

Run jq-compatible JSON filters without installing a separate binary:

```sh
printf '%s' '{"name":"Moon"}' | moonx mooxCLI/cmd/jq -r '.name'
moonx mooxCLI/cmd/jq -n -c '{ok: true, values: [1, 2]}'
moonx mooxCLI/cmd/jq -c '.items[]' data.json
```

`moonx` uses the linear-memory WebAssembly build by default. Arguments after
`mooxCLI/cmd/jq` are passed directly to the jq-compatible command.

Supported options:

- `-c`, `--compact-output`: print compact JSON.
- `-r`, `--raw-output`: print strings without JSON quotes.
- `-f`, `--from-file FILE`: read the filter from `FILE`.
- `-n`, `--null-input`: evaluate once with `null` input.
- `-l`, `--logs`: process newline-delimited JSON and skip invalid lines.
