# rev

Reverse each input record for MoonX.

```sh
moonx cli/rev@0.1.6 [OPTION]... [FILE]...
```

## Supported scope

Read files or stdin and reverse each record, retaining its terminator.

## Options

| Option | Description |
| --- | --- |
| `--help` / `--version` | Show help / package version. |

## Limitations

The local development candidate batches ASCII validation and reversal into a fixed 64 KiB output buffer; cross-chunk records still require longest-record storage.

- The supported C profile rejects non-ASCII records. Memory grows with the longest record.
- An explicit `-` is a filename, not stdin; omit file operands to read stdin.

## Examples

```sh
printf 'abc\n' | moonx cli/rev@0.1.6
moonx cli/rev@0.1.6 notes.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
