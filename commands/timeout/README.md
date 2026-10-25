# timeout

Workspace version: **0.2.1 candidate, unpublished**. This package remains
local-only; see the [support record](../../docs/compatibility.md).

Run one command with a millisecond-precise wall-clock limit. Durations accept
plain seconds or `ms`, `s`, `m`, `h`, and `d` suffixes. A timed-out command is
forcefully cancelled and returns status 124. Durations round up to whole
milliseconds and must fit the runtime timer range of 0 through 2,147,483,647 ms.
Process-group termination,
`--kill-after`, `--foreground`, `--preserve-status`, and signal selection are
unsupported because the
portable API only provides cancellation for the directly owned child process.
Unlike `sh`, `make`, and `xargs`, this difference from GNU `timeout` keeps the
command behind its compatibility release gate. It is included in the
79-command local build but is
not one of the 78 command modules currently available from Mooncakes;
`moonx cli/timeout` is intentionally unsupported.

The child inherits the complete caller environment. The caller or host grants
process access; this command does not implement an authorization allowlist.
Normal completion returns the child status, timeout returns 124, invalid setup
returns 125, and child launch errors return 126/127.

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target wasm --release commands/timeout -- 1s printf ok
```

`--` ends option parsing before the duration; subsequent arguments belong to
the child command. Use `--help` to display usage.

## Standalone metadata

Standalone `--version` prints exactly `timeout 0.2.1` followed by one
newline. Standalone `--help` starts with `Usage: timeout`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. These local metadata contracts do not change
the package's local-only release status.
