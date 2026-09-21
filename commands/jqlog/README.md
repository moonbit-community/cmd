# jqlog

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

`cli/jqlog` applies a jq-compatible filter to each valid JSON line and skips
non-JSON lines. The first operand is the filter; an optional second operand is
raw input text (`-` selects stdin). `-f/--file PATH` reads input from a file,
and `-h/--help` prints usage. File-access authorization belongs to the caller
or host. The evaluator remains MoonJQ 0.1.2.

`--help` and parser errors always end with a newline so output can be safely
composed with other command-line tools.

```sh
cat logs.ndjson | moon run --target wasm --release commands/jqlog -- '.message'
```
