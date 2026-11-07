# split

Published package: `cli/split@0.1.7`, using `cli/core@0.9.2`.
Dated exact-coordinate acceptance is recorded in the
[changelog](../../CHANGELOG.md#2026-11-08).

Split input into pieces for MoonX.

```sh
moonx cli/split@0.1.7 [OPTION]... [FILE [PREFIX]]
```

## Supported scope

Split files or stdin by records, bytes, bounded line bytes or N-way partitions. Default is 1000 records per piece with names xaa, xab, etc.

Filter sessions inherit the shared shell's arithmetic assignments, backticks,
expanded here-documents, standard stream aliases, loop control and finite
printf/test profile. See [sh](../sh/README.md) for grammar and API boundaries.

## Options

| Option | Description |
| --- | --- |
| `-l, --lines=NUMBER` | put NUMBER records in each piece (default 1000) |
| `-b, --bytes=SIZE` | put SIZE bytes in each piece |
| `-C, --line-bytes=SIZE` | put at most SIZE bytes of records in each piece |
| `-n, --number=CHUNKS` | N, K/N, l/N, l/K/N, r/N or r/K/N |
| `-a, --suffix-length=N` | fixed suffix width; zero selects automatic width |
| `-d, --numeric-suffixes[=FROM]` | numeric suffixes |
| `-x, --hex-suffixes[=FROM]` | hexadecimal suffixes |
| `--additional-suffix=SUFFIX` | append SUFFIX to generated names |
| `-e, --elide-empty-files` | omit empty outputs |
| `--filter=COMMAND` | run pure shell source per piece with FILE set |
| `--help` / `--version` | Show help / package version. |

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Existing named outputs are refused; failures retain completed pieces.
- --filter uses the supported sh subset and cannot combine with selected K/N stdout output. Round-robin filters can run concurrently.
- Some modes require writable temporary storage.

## Examples

```sh
moonx cli/split@0.1.7 -l 100 input.txt part-
moonx cli/split@0.1.7 -b 64K -d input.bin chunk-
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
