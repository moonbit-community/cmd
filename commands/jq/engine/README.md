# jq engine

Compile a jq-compatible filter and apply it to supplied JSON values without I/O.

## Usage

Import cli/jq/engine as engine and moonbitlang/core/json as json:

```moonbit
let filter = @engine.compile(".name")
let results = filter.apply(@json.parse("{\"name\":\"Moon\"}"))
assert_eq(results, [@json.parse("\"Moon\"")])
```

| API | Purpose |
| --- | --- |
| compile(source) | Compile a filter and validate lexical references. |
| Filter::apply(value) | Start a fresh scope and return all results on success. |

## Notes

- Errors raise instead of returning a partial result array. A compiled filter
  can be reused across values without carrying bindings between applications.
- Module imports are rejected. Evaluated input/input-metadata/module-metadata
  requests fail explicitly; the engine does not read files or consume later
  records. The jq CLI supplies its own module loader and shared input cursor.
- The language and numeric limits are shared with
  [jq](../README.md). Use cli/jq 0.2.10 or later for this API; see the
  [compatibility guide](../../../docs/compatibility.md) for its supported profile.
