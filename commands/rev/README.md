# rev

Development candidate: `cli/rev@0.1.8`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Reverse each input record for MoonX.

```sh
moonx cli/rev@0.1.8 [OPTION]... [FILE]...
```

## Supported scope

Read files or stdin and reverse each record, retaining its terminator.

## Options

| Option | Description |
| --- | --- |
| `--help` / `--version` | Show help / package version. |

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

The local development candidate batches ASCII validation and reversal into a fixed 64 KiB output buffer; cross-chunk records still require longest-record storage.

- The supported C profile rejects non-ASCII records. Memory grows with the longest record.
- An explicit `-` is a filename, not stdin; omit file operands to read stdin.

## Examples

```sh
printf 'abc\n' | moonx cli/rev@0.1.8
moonx cli/rev@0.1.8 notes.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
