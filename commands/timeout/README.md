# timeout

Limit command execution time for MoonX (not yet published).

```sh
moon run --target wasm --release commands/timeout -- DURATION COMMAND [ARG...]
```

## Supported scope

Run one child with a wall-clock limit. Normal completion returns its status; timeout returns 124, setup errors 125 and launch errors 126/127.

## Options

| Option | Description |
| --- | --- |
| `DURATION COMMAND [ARG...]` | Duration accepts seconds or ms, s, m, h, d suffixes. |
| `--` | End option parsing before the duration. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Local-only: moonx cli/timeout is unavailable.
- Process-group termination, signal selection, --kill-after, --foreground and --preserve-status are unsupported.
- Durations round up to milliseconds and must fit 0 through 2147483647 ms.

## Examples

```sh
moon run --target wasm --release commands/timeout -- 1s printf ok
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0006-process.md)
