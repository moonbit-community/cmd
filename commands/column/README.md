# column

Arrange text into columns for MoonX.

```sh
moonx cli/column@0.1.6 [OPTION]... [FILE]...
```

## Supported scope

Arrange files or stdin in a grid, or align delimited fields as a table. Default width is COLUMNS or 80.

## Options

| Option | Description |
| --- | --- |
| `-t, --table` | create a table |
| `-s, --separator=CHARS` | table delimiters (default: space and TAB) |
| `-o, --output-separator=SEP` | table separator (default: two spaces) |
| `-c, --output-width=WIDTH` | output width (default: COLUMNS or 80) |
| `-x, --fillrows` | fill rows before columns |
| `--help` / `--version` | Show help / package version. |

## Limitations

The local development candidate batches snapshot data/index writes and expanded table output; a wide table does not require a complete padded output row in memory. Input uses immutable chunks up to 1 MiB, with separate 64 KiB pending data/index buffers and at most one deferred encoded record. The complete input snapshot and C-locale display rules are retained.

Table rendering now borrows normalized byte fields. Field splitting and width collection share one ingestion pass. Optional field metadata is limited to 128 large rows and 64 KiB of encoded entries, with no extra snapshot-disk format. These limits exclude the current row, global column widths and runtime overhead; they are not a process-memory cap.

- Non-ASCII bytes display as \xHH; locale-aware display widths are unsupported.
- Requires writable temporary storage; output starts after the input pass.

## Examples

```sh
moonx cli/column@0.1.6 -t table.txt
moonx cli/column@0.1.6 -t -s , -o ' | ' data.csv
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
