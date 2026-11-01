# xxd

Create and reverse hex dumps for MoonX.

```sh
moonx cli/xxd@0.2.4 [OPTION]... [INFILE [OUTFILE]]
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

## Limitations

- Existing output files are rejected. Backward stdin seeks and backward writes to stdout are unsupported.
- Reverse little-endian and include modes are unsupported.

## Examples

```sh
moonx cli/xxd@0.2.4 -p data.bin
printf '68690a' | moonx cli/xxd@0.2.4 -r -p
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0008-data.md)
