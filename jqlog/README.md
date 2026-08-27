# jqlog

`mooxCLI/cmd/jqlog` is the JSON Lines companion command in this module. It
supports native and Wasm execution, applies a jq-compatible filter to each
valid JSON line, and skips non-JSON lines. File reads remain visible to the
configured Wasm policy.

```sh
cat logs.ndjson | moon run --target wasm jqlog -- '.message'
```
