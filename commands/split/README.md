# split

Published: `cli/split@0.1.10`, using `cli/core@0.9.5`.
Three-platform exact-coordinate acceptance and earlier release evidence are recorded in the
[changelog](../../CHANGELOG.md#2026-11-08).

Split input into pieces for MoonX.

```sh
moonx cli/split@0.1.10 [OPTION]... [FILE [PREFIX]]
```

## Supported scope

Split files or stdin by records, bytes, bounded line bytes or N-way partitions. Default is 1000 records per piece with names xaa, xab, etc.

Filter `test -s` follows final targets and queries metadata without opening them.
Missing/cyclic targets are false; unavailable sizes such as macOS directories
produce explicit shell errors. Filters retain responsibility for handling errors
and for their explicit output files. On POSIX, every file predicate and both
timestamp-comparison operands require a trailing slash to name a directory.
Directory links ending in a slash select their directory, so -L/-h are false;
unsuffixed links retain their ordinary behavior.

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

Filter syntax errors, including unmatched reserved words and empty required
compound lists, fail before that command list writes files. The filter's actual
status propagates and its owned input/task is closed by the existing lifecycle.
A complete filter ending in backslash-LF executes at EOF; genuinely unfinished
syntax still fails.

```sh
moonx cli/split@0.1.10 -l 100 input.txt part-
moonx cli/split@0.1.10 -b 64K -d input.bin chunk-
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
