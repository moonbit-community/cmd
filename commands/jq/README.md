# jq for moonx

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

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
- `-j`, `--join-output`: print strings without quotes and omit separators between filter results.
- `-s`, `--slurp`: evaluate one array containing all input values.
- `-R`, `--raw-input`: treat each input line as a JSON string.
- `-e`, `--exit-status`: return 1 for false/null and 4 when no result is produced.
- `--arg NAME VALUE`, `--argjson NAME JSON`: bind values lexically for `$NAME`,
  including string interpolation and local variable shadowing.
- `--indent N` and `--tab`: select pretty-print indentation. `N` ranges from
  `-1` (tabs) through `7`; `0` preserves line breaks without indentation.
  The last of `-c`, `--indent` and `--tab` selects formatting.
- `-C`, `--color-output`: emit jq 1.8.2 ANSI colors, including on redirected output.
- `-M`, `--monochrome-output`: disable colors; this wins over `-C` in either order.

`JQ_COLORS` supplies colon-separated SGR codes for null, false, true, numbers,
strings, arrays, objects and object keys. Omitted palette entries retain their
defaults; invalid values warn on stderr and use the default palette, without
changing the query's exit status. Raw string results (`-r`/`-j`) remain uncolored.
Without `-C`, output is monochrome: automatic TTY detection awaits a public
`isatty` API. Explicit `-C` works independently of `NO_COLOR`, as in upstream jq.
`-l/--logs` is a project extension and cannot be combined with `-n` or `-R`.

Ordinary input accepts consecutive JSON values, including multiline objects,
and emits completed values before EOF. `-s` collects all JSON values from all
inputs; `-Rs` collects their exact text as one string. Parsing errors preserve
already emitted results and exit with status 4. `-n` evaluates once without
reading input files; `-e` reflects the final emitted value. With no filter the
identity filter is used.

The evaluator is MoonJQ 0.1.2. Its map, reduce,
assignment, and try/catch slices are usable through this CLI; modules,
the `--stream` event representation, and every jq 1.8.2 diagnostic are not claimed.
