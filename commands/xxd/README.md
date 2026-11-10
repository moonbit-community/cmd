# xxd

Published version: `cli/xxd@0.2.6`. See the release inventory;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Create and reverse hex dumps for MoonX.

```sh
moonx cli/xxd@0.2.6 [OPTION]... [INFILE [OUTFILE]]
```

## Supported scope

Display files or stdin as hex, bits or include text; reverse addressed hex, plain hex or binary dumps.

## Options

| Option | Description |
| --- | --- |
| `-a, --autoskip` | toggle suppression of zero lines |
| `-b, --bits` | binary digit display |
| `-e, --little` | little-endian groups |
| `-E, --ebcdic` | EBCDIC character display |
| `-g, --group=N` | bytes per group |
| `-u, --upper` | uppercase hexadecimal digits |
| `-o, --offset=N` | add N to displayed offsets |
| `-p, -ps, --plain` | plain hexadecimal display |
| `-i, --include` | C include display |
| `-r, --reverse` | reverse a dump |
| `-c, --cols=N` | bytes per line |
| `-l, --len=N` | maximum input bytes |
| `-s, --seek=[+][-]N` | input seek or reverse address adjustment |
| `-n, --name=NAME` | C include symbol |
| `--help` / `--version` | Show help / package version. |

## Extension and diagnostic contract

Project aliases: --little/-littleendian select -e; --ebcdic/-ebcdic select -E.
Project long-option syntax also accepts =VALUE for --cols, --group, --len,
--name, --offset and --seek; these forms are not Vim xxd argument equivalence.
-h/--help use the project metadata contract: stdout and status 0.

See [the finite option and diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics) for the scope and upstream distinction.

## Argument and exit-status contract

Usage errors exit 1; runtime errors retain their command-specific statuses:
input/open errors use 2, output errors use 3, input seek errors use 4, and
backward output/offset errors use 5. Option values and operands after `--`
remain literal.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Existing output files are rejected. Backward stdin seeks and backward writes to stdout are unsupported.
- Reverse little-endian and include modes are unsupported.

## Examples

```sh
moonx cli/xxd@0.2.6 -p data.bin
printf '68690a' | moonx cli/xxd@0.2.6 -r -p
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0008-data.md)
