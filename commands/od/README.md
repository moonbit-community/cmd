# od

Development candidate: `cli/od@0.1.5`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Display numeric and character data for MoonX.

```sh
moonx cli/od@0.1.5 [OPTION]... [FILE]...
```

## Supported scope

Concatenate files or stdin and display integer, floating or character values. Default output is two-byte octal with octal addresses.

## Options

| Option | Description |
| --- | --- |
| `-A, --address-radix=d\|o\|x\|n` | address base, or no addresses |
| `-j, --skip-bytes=N` | skip N input bytes |
| `-N, --read-bytes=N` | print at most N bytes |
| `-t, --format=TYPE` | a, c, integers 1/2/4/8; floats 2/4/8/16; optional z |
| `-a -b -c -d -i -l -o -s -x` | traditional named/integer formats |
| `-f -e -F` | traditional float or double formats |
| `--endian=little\|big` | byte order (default little) |
| `-w[N], --width[=N]` | bytes per line (default 16, bare option 32) |
| `-v, --output-duplicates` | do not replace repeated blocks with * |
| `-S N, --strings[=N]` | print NUL-terminated printable strings (default 3) |
| `--traditional` | accept old offset and label operands |
| `--help` / `--version` | Show help / package version. |

## Extension and diagnostic contract

Project format aliases: --named = -a; --octal-byte = -b; --character = -c.
--decimal = -d; --int = -i; --long = -l; --octal = -o; --signed = -s.
--hex = -x; --float = -f; --double = -e; --double-F = -F.

See [the finite option and diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics) for the scope and upstream distinction.

## Limitations

- Characters use C-byte rules. Floating formats follow the GNU Linux amd64 profile on every host.
- Output widths are limited to 1048576 bytes; incompatible widths use the common type size with a warning.

## Examples

```sh
moonx cli/od@0.1.5 -Ax -tx1 data.bin
moonx cli/od@0.1.5 -j4 -N8 --endian=big -tx2 data.bin
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0008-data.md)
