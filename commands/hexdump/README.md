# hexdump

Display binary data for MoonX.

```sh
moonx cli/hexdump@0.1.3 [OPTION]... [FILE]...
```

## Supported scope

Concatenate files or stdin and display numeric/character formats. Supports custom formats, byte limits, skips and explicit color rules.

## Options

| Option | Description |
| --- | --- |
| `-b, --one-byte-octal` | one-byte octal |
| `-c, --one-byte-char` | escaped characters |
| `-C, --canonical` | hexadecimal bytes with ASCII |
| `-d, --two-bytes-decimal` | two-byte unsigned decimal |
| `-o, --two-bytes-octal` | two-byte octal |
| `-x, --two-bytes-hex` | two-byte hexadecimal |
| `-X, --one-byte-hex` | one-byte hexadecimal |
| `-e, --format=FORMAT` | add a custom format |
| `-f, --format-file=FILE` | add formats from a file |
| `-L, --color[=WHEN]` | enable _L colors: always, auto, or never |
| `-n, --length=N` | display at most N input bytes |
| `-s, --skip=N` | skip N input bytes |
| `-v, --no-squeezing` | display duplicate blocks |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Numeric words use little-endian byte order. Locale-aware character rendering is unsupported.
- Automatic terminal color is unavailable; auto remains uncolored. Custom %% conversions are rejected.

## Examples

```sh
moonx cli/hexdump@0.1.3 -C data.bin
moonx cli/hexdump@0.1.3 -s16 -n32 -v data.bin
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0008-data.md)
