# strings

Extract printable byte sequences for MoonX.

```sh
moonx cli/strings@0.1.4 [OPTION]... [FILE]...
```

## Supported scope

Scan complete files or stdin for runs of at least four printable bytes by default. TAB belongs to a printable run.

## Options

| Option | Description |
| --- | --- |
| `-a, --all` | scan the whole file |
| `-f, --print-file-name` | print the file name before each string |
| `-n, --bytes=N` | print sequences at least N bytes long |
| `-o` | display offsets in octal |
| `-t, --radix=RADIX` | display offsets in d, o, or x radix |
| `-e, --encoding=ENC` | s: 7-bit bytes (default); S: 8-bit bytes |
| `-s, --output-separator=STR` | separate accepted strings with STR |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Wide encodings, object-section selection, locale decoding and GNU Unicode rendering modes are unsupported.

## Examples

```sh
moonx cli/strings@0.1.4 -n 6 -t d data.bin
printf 'hello\000world\n' | moonx cli/strings@0.1.4
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0008-data.md)
