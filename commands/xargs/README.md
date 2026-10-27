# xargs

Build and execute argument batches for MoonX.

```sh
moonx cli/xargs@0.2.3 [-0prt] [-d BYTE] [-n N] [-L N] [-s BYTES] [-P N] [-E EOF] [-I REPLACE] [COMMAND [ARG...]]
```

## Supported scope

Read items from stdin and launch commands directly, with whitespace/quote parsing, delimiter modes, replacement and bounded parallelism.

## Options

| Option | Description |
| --- | --- |
| `-0 / -d, --delimiter=BYTE` | Read NUL-delimited / selected-byte items. |
| `-n, --max-args=N / -L, --max-lines=N` | Limit arguments / input lines per invocation. |
| `-s, --max-chars=BYTES` | Limit argument bytes; default 64 KiB. |
| `-E, --eof=TEXT` | Stop at the selected logical EOF in whitespace mode. |
| `-r, --no-run-if-empty` | Do not invoke the command for empty input. |
| `-I, --replace=TEXT` | Replace TEXT using logical input lines. |
| `-P N` | Run at most N batches concurrently. |
| `-t, --verbose / -p, --interactive` | Print commands / confirm through a separate console. |
| `--show-limits` | Show argument limits. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Arguments are not shell-evaluated. Non-UTF-8 argument prefixes are rejected before launch.
- Interactive mode requires a separate confirmation channel; failure to open it returns 2 before reading stdin.
- Process-group cancellation is unsupported; parallel output order is unspecified.

## Examples

```sh
printf 'one\ntwo\n' | moonx cli/xargs@0.2.3 -n 1 moonx cli/echo@0.2.3
printf 'one\000two\000' | moonx cli/xargs@0.2.3 -0 moonx cli/echo@0.2.3
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0006-process.md)
