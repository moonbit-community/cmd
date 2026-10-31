# jqlog

Filter JSON log lines for MoonX.

```sh
moonx cli/jqlog@0.2.4 [options] <query> [input]
```

## Supported scope

Apply a jq-compatible filter to each valid JSON line and emit compact JSON. Read stdin by default, or pass raw input as the second operand.

## Options

| Option | Description |
| --- | --- |
| `-f, --file PATH` | Read log input from a file. |
| `FILTER [TEXT]` | Select a filter and optional literal input; - means stdin. |
| `--` | End options before a filter beginning with -. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Invalid JSON lines are skipped. Filter errors return failure and preserve earlier results.
- Supports the same bounded filter language as jq; not the full jq CLI.
- The unreleased shared adapter preserves complete grouping/sorting key streams and stable ties. Exact numeric ordering at or above 2^53 remains outside the verified key domain.

## Examples

```sh
moonx cli/jqlog@0.2.4 -f logs.ndjson '.message'
printf '%s\n' '{"level":"info"}' | moonx cli/jqlog@0.2.4 '.level'
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0007-language.md)
