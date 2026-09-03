# jqlog

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

`cli/jqlog` is the JSON Lines companion command in this module. The observed
Wasm artifact applies a jq-compatible filter to each valid JSON line and skips
non-JSON lines. File reads remain visible to the configured Wasm policy.

```sh
cat logs.ndjson | moon run --target wasm --release commands/jqlog -- '.message'
```
