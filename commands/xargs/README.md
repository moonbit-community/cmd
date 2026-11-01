# xargs

Build and execute argument batches for MoonX.

```sh
moonx cli/xargs@0.2.4 [-0prt] [-d BYTE] [-n N] [-L N] [-s BYTES] [-P N] [-E EOF] [-I REPLACE] [COMMAND [ARG...]]
```

## Supported scope

Read items from stdin and launch commands directly, with whitespace/quote parsing, delimiter modes, replacement and bounded parallelism.

Complete `-n`/`-L` batches can run before stdin reaches EOF. The producer waits
when all `-P` slots are occupied, and each completed child frees a slot without
waiting for its peers. Argument bytes are counted incrementally; input items
and pending batches are bounded by the configured size limit. `--show-limits`
does not consume stdin. Interactive confirmations remain serialized.

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
- Earlier batches may already have completed when later input is malformed or
  untransportable. Fatal child statuses stop further dispatch; already running
  children are awaited. Replacement results must also fit the argument budget.

## Examples

```sh
printf 'one\ntwo\n' | moonx cli/xargs@0.2.4 -n 1 moonx cli/echo@0.2.3
printf 'one\000two\000' | moonx cli/xargs@0.2.4 -0 moonx cli/echo@0.2.3
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0006-process.md)
