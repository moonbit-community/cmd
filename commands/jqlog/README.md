# jqlog

Version **0.2.3** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

`cli/jqlog` applies a jq-compatible filter to each valid JSON line and skips
non-JSON lines. The first operand is the filter; an optional second operand is
raw input text (`-` selects stdin). `-f/--file PATH` reads input from a file,
and `-h/--help` prints usage. File-access authorization belongs to the caller
or host. The evaluator is MoonJQ 0.2.0 with the same string-conversion and
Unicode-scalar slice adapter as `cli/jq`. Invalid JSON lines are skipped;
filter evaluation errors return nonzero and preserve results already written.

`--help` and parser errors always end with a newline so output can be safely
composed with other command-line tools.

```sh
cat logs.ndjson | moon run --target wasm --release commands/jqlog -- '.message'
```

## Standalone metadata

Standalone `--version` prints exactly `jqlog 0.2.3` followed by one
newline. Standalone `--help` starts with `Usage: jqlog`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
