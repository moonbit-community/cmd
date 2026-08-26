# jqlog

`mooxCLI/cmd/jqlog` is the native JSON Lines companion command in this module.
It applies a jq-compatible filter to each valid JSON line and skips non-JSON
lines.

```sh
cat logs.ndjson | moon run --target native jqlog -- '.message'
```
