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

- Empty regex separators and locale-aware matching are unsupported.
- Stdin/nonregular inputs and regex mode require temporary storage. Regex mode also retains input in memory.

## Examples

```sh
printf 'one\ntwo\n' | moonx cli/tac@0.1.5
moonx cli/tac@0.1.5 -s '--' records.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
