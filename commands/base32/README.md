# base32

Encode and decode Base32 for MoonX.

Workspace candidate: `cli/base32@0.1.5` (unreleased). Published coordinates
remain recorded in the [release inventory](../../tests/release_runner/current/latest.json).

```sh
moonx cli/base32@0.1.5 [-d] [-i] [-w COLS] [FILE]
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

## Limitations

- Lowercase symbols are invalid unless discarded with `-i`; malformed input can fail after emitting a valid prefix.
- Nonstandard alphabets and locale-specific behavior are unsupported.
- Decoding still reads the complete input before processing it; the encoding
  memory bound does not apply to decoding.

## Examples

```sh
printf 'hello' | moonx cli/base32@0.1.5
printf 'NBSWY3DP' | moonx cli/base32@0.1.5 -d
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0008-data.md)
