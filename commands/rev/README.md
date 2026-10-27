# rev

Reverse each input record for MoonX.

```sh
moonx cli/rev@0.1.5 [OPTION]... [FILE]...
```

## Supported scope

Read files or stdin and reverse each record, retaining its terminator.

## Options

| Option | Description |
| --- | --- |
| `--help` / `--version` | Show help / package version. |

## Limitations

- The supported C profile rejects non-ASCII records. Memory grows with the longest record.
- An explicit `-` is a filename, not stdin; omit file operands to read stdin.

## Examples

```sh
printf 'abc\n' | moonx cli/rev@0.1.5
moonx cli/rev@0.1.5 notes.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
