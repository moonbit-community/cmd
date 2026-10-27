# base64

Encode and decode Base64 for MoonX.

```sh
moonx cli/base64@0.2.3 [-d|-D] [-i] [-w COLS] [FILE]
```

## Supported scope

Encode files or stdin using the standard alphabet and `=` padding. With no file, or `-`, read stdin. Default output width is 76.

## Options

| Option | Description |
| --- | --- |
| `-d, -D, --decode` | Decode input; embedded newlines are accepted. |
| `-i, --ignore-garbage` | Discard non-alphabet bytes while decoding. |
| `-w, --wrap=COLS` | Set output width; 0 disables wrapping and the final newline. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Ignoring garbage does not make malformed Base64 valid.

## Examples

```sh
printf 'hello' | moonx cli/base64@0.2.3
moonx cli/base64@0.2.3 -d encoded.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0008-data.md)
