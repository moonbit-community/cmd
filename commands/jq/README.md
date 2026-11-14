# jq

Version: `cli/jq@0.2.9`.

Filter JSON for MoonX.

```sh
moonx cli/jq@0.2.9 [OPTION]... [FILTER] [FILE...]
```

## Supported scope

Apply jq-compatible filters to consecutive JSON values, files or stdin. Supports maps, reduce, assignments, try/catch, variables and Unicode string slices. No filter selects identity.

The parser and evaluator are maintained locally in `internal/parser` and
`internal/ast`; command adaptations and streaming I/O live in `internal/driver`.
Jq no longer depends on the MoonJQ package. The minimal imported language
implementation and its original tests come from the verified 0.2.0 archive;
see [third-party notices](THIRD_PARTY_NOTICES.md).

## Options

| Option | Description |
| --- | --- |
| `-c, --compact-output` | print compact JSON |
| `-r, --raw-output` | print strings without JSON quotes |
| `-j, --join-output` | raw output without result separators |
| `-n, --null-input` | evaluate once with null; `input`/`inputs` can still read |
| `-s, --slurp` | collect input values in an array |
| `-R, --raw-input` | read text lines; -Rs reads all text |
| `-l, --logs` | skip non-JSON lines (project extension) |
| `--stream` | emit incremental path/leaf and container-end events |
| `--stream-errors` | emit parse-error events and resume at the next parser buffer |
| `-S, --sort-keys` | sort object keys recursively |
| `-e, --exit-status` | return 1 for false/null, 4 for no result |
| `-f, --from-file` | read the first positional argument as a filter file |
| `--arg NAME VALUE` | bind a string variable |
| `--argjson NAME JSON` | bind a JSON variable |
| `-L DIRECTORY` | replace default module paths; repeated paths are searched in order |
| `--indent N` | indentation -1 (tabs) through 7 |
| `--tab` | indent with tabs |
| `-C, --color-output` | emit ANSI colors (JQ_COLORS customizes the palette) |
| `-M, --monochrome-output` | disable colors, including when -C is present |
| `--help` / `--version` | Show help / package version. |

## Argument and exit-status contract

Option values and operands after -- remain literal during alias normalization.

`-f`/`--from-file` is a mode flag, matching jq 1.8.2: the first positional
argument names the filter file, and later positionals name input files. Options
can occur before or after the filename. Repeated `-f` is idempotent; it does not
select multiple filters. Use `-f -- --arg input` for a filter filename `--arg`,
or prefix the filename with `./`. Missing filenames and attached long values
(`--from-file=FILE`) reject; `-f --arg input` still parses `--arg` as an option.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Streaming input

- `--stream` incrementally emits `[path, leaf]` and `[path]` container endings.
  Empty arrays/objects are leaves. Duplicate keys, consecutive documents and
  output before a later parse/read failure are retained. Input files form one
  byte stream, so tokens and containers may cross file boundaries. The reader stores one
  64 KiB chunk, one scalar token and the nesting path; `--slurp` deliberately
  collects events. Existing raw/null modes keep their input precedence.
- `--stream-errors` emits `[message, path]` and discards the remainder of the
  fixed CLI parser buffer before resuming. It implies `--stream`. Literal
  decimal precision and exponent formatting are retained independently of the
  evaluator's existing floating-point arithmetic limits.

## Functions, modules and shared input

`input` consumes the next value and raises a catchable `break` error at EOF;
`inputs` produces the remaining values. Both share the outer input loop's
cursor, including files, raw/slurp modes and stream events. `first`, `limit`,
`any` and `all` stop reading when their result is decided. Files open on demand;
missing operands report an error, allow later files, and retain exit status 2.
`input_filename` and `input_line_number` describe the current input source.

Functions capture their definition's lexical scope. Filter parameters run on
each invocation with the caller's bindings and the current input; `$value`
parameters evaluate once per argument result. Functions overload by arity.

`import "name" as prefix;` exposes `prefix::function`; `include "name";`
exposes functions without a prefix. Dependencies and helper bindings remain
private to their defining module. `import "name" as $data;` reads JSON values
into an array; `{raw:true}` reads text and `{optional:true}` permits missing or
unreadable data without defining a binding. Invalid library syntax still fails.
`module {...};` and `modulemeta` expose metadata, dependencies and definitions.
Metadata permits finite constant-folding expressions; effects and generators
are rejected before evaluation. Invalid library syntax during `modulemeta`
prints a diagnostic and returns null.
Search checks `name.jq`, `name/jq/main.jq`, then `name/name.jq`. Import metadata
`search` replaces that import's search list; `"."` names the working directory,
while `"./"` is relative to the importing file. Defaults include `~/.jq` and
paths relative to the executable argument (`$ORIGIN`); a regular `~/.jq` file
is loaded as a prelude independently of `-L`.
On Windows, an absent `HOME` falls back to `USERPROFILE`, then to
`HOMEDRIVE` plus `HOMEPATH`.

## Limitations

- Module and input support applies to the owned filter language. Full jq
  compatibility, all builtin signatures and complete upstream diagnostics
  remain outside the verified profile. See ADR-0008 for validation boundaries.
- Color requires explicit -C; automatic terminal color is unavailable. -l/--logs skips invalid lines and conflicts with -n/-R.
- The adapter preserves complete `group_by`/`sort_by` key streams and stable ties. Grouping canonicalizes object key order and safe numeric representations; numeric ordering at or above 2^53 still follows the imported floating-point comparison and is not claimed exact.

## Examples

```sh
printf '%s' '{"name":"Moon"}' | moonx cli/jq@0.2.9 -r '.name'
moonx cli/jq@0.2.9 -n -c '{ok: true, values: [1, 2]}'
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0008-data.md)
