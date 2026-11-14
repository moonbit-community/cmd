# jqlog

Filter JSON log lines for MoonX.

Development candidate: `cli/jqlog@0.2.7`. The published coordinate remains
`cli/jqlog@0.2.6` until a separate release.

```sh
moonx cli/jqlog@0.2.6 [options] <query> [input]
```

## Supported scope

Apply a jq-compatible filter to each valid JSON line and emit compact JSON. Read stdin by default, or pass raw input as the second operand.

The parser, AST, evaluator and command logic are maintained under `internal`;
the command no longer depends on MoonJQ. See
[third-party notices](THIRD_PARTY_NOTICES.md) for source and license details.

## Options

| Option | Description |
| --- | --- |
| `-f, --file PATH` | Read log input from a file. |
| `FILTER [TEXT]` | Select a filter and optional literal input; - means stdin. |
| `--` | End options before a filter beginning with -. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Invalid JSON lines are skipped. Filter errors return failure and preserve earlier results.
- Retains its imported bounded filter language. Jq's new module loader,
  lexical filter closures and shared `input`/`inputs` cursor are separate
  command features and are not enabled by this ownership migration.
- The command's adapter preserves complete grouping/sorting key streams and stable ties. Exact numeric ordering at or above 2^53 remains outside the verified key domain.

## Examples

```sh
moonx cli/jqlog@0.2.6 -f logs.ndjson '.message'
printf '%s\n' '{"level":"info"}' | moonx cli/jqlog@0.2.6 '.level'
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0007-language.md)
