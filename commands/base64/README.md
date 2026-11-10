# base64

Development candidate: `cli/base64@0.2.7`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Encode and decode Base64 for MoonX.

```sh
moonx cli/base64@0.2.7 [-d|-D] [-i] [-w COLS] [FILE]
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

## Extension and diagnostic contract

Project alias: -D selects -d/--decode; -D is not a GNU coreutils option.
Decoding retains determined bytes before invalid input, checks canonical tail bits,
and accepts missing final padding or concatenated padded groups (GNU 9.11).

See [the finite option and diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics) for the scope and upstream distinction.

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Ignoring garbage does not make malformed Base64 valid.

## Examples

```sh
printf 'hello' | moonx cli/base64@0.2.7
moonx cli/base64@0.2.7 -d encoded.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0008-data.md)
