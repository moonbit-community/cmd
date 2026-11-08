# base32

Development candidate: `cli/base32@0.1.6`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Encode and decode Base32 for MoonX.

Version: `cli/base32@0.1.6`. Published coordinates
remain recorded in the [release inventory](../../tests/release/latest.json).

```sh
moonx cli/base32@0.1.6 [-d] [-i] [-w COLS] [FILE]
```

## Supported scope

Encode files or stdin with the RFC 4648 alphabet. With no file, or `-`, read stdin. Output wraps at 76 columns by default.

Encoding emits complete groups as input arrives and keeps bounded working
buffers. Padding and a final wrapped newline are emitted only at successful
EOF; a later read or write error can leave earlier output intact.

## Options

| Option | Description |
| --- | --- |
| `-d, --decode` | Decode input. |
| `-i, --ignore-garbage` | Ignore non-alphabet bytes when decoding. |
| `-w, --wrap=COLS` | Set output width; 0 disables wrapping and the final newline. |
| `--help` / `--version` | Show help / package version. |

## Extension and diagnostic contract

Decoding checks canonical tail bits and preserves complete-block failure prefixes.
Missing final padding is accepted; incomplete explicit padding rejects (GNU 9.11).

See [the finite option and diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics) for the scope and upstream distinction.

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Lowercase symbols are invalid unless discarded with `-i`; malformed input can fail after emitting a valid prefix.
- Nonstandard alphabets and locale-specific behavior are unsupported.
- Decoding still reads the complete input before processing it; the encoding
  memory bound does not apply to decoding.

## Examples

```sh
printf 'hello' | moonx cli/base32@0.1.6
printf 'NBSWY3DP' | moonx cli/base32@0.1.6 -d
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0008-data.md)
