# tac

Reverse record order for MoonX.

```sh
moonx cli/tac@0.1.5 [OPTION]... [FILE]...
```

## Supported scope

Reverse records from each file or stdin, preserving separator bytes and missing final separators. Default separator is LF.

## Options

| Option | Description |
| --- | --- |
| `-s, --separator=STRING` | Set a separator; empty fixed separator means NUL. |
| `-b, --before` | Attach separators to the following record. |
| `-r, --regex` | Interpret the separator using GNU Emacs byte regex syntax. |
| `--help` / `--version` | Show help / package version. |

## Limitations

The local development candidate batches fixed-separator ranges within each 64 KiB block, including multi-byte separators. With no partial separator match, it skips bytes that cannot start a reverse match. Input spooling and cross-block record semantics are unchanged; memory remains bounded by the block and separator sizes.

- Empty regex separators and locale-aware matching are unsupported.
- A local GNU 9.11 comparison retains a long repeated-input difference with the overlapping fixed separator `aa`; see [ADR-0003](../../docs/adr/0003-streams.md#local-continuation-after-the-documentation-release-2026-10-27).
- Stdin/nonregular inputs and regex mode require temporary storage. Regex mode also retains input in memory.

## Examples

```sh
printf 'one\ntwo\n' | moonx cli/tac@0.1.5
moonx cli/tac@0.1.5 -s '--' records.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
