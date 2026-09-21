# timeout

Workspace version: **0.2.0 candidate, unpublished**. This package remains
local-only; see the [support record](../../docs/compatibility.md).

Run one command with a millisecond-precise wall-clock limit. Durations accept
plain seconds or `ms`, `s`, `m`, `h`, and `d` suffixes. A timed-out command is
forcefully cancelled and returns status 124. Process-group termination,
`--kill-after`, `--foreground`, `--preserve-status`, and signal selection are
unsupported because the
portable API only provides cancellation for the directly owned child process.
Unlike `sh`, `make`, and `xargs`, this difference from GNU `timeout` keeps the
command behind its compatibility release gate. It is included in the
48-command local build but is
not one of the 47 command modules currently available from Mooncakes;
`moonx cli/timeout` is intentionally unsupported.

The child inherits the complete caller environment. The caller or host grants
process access; this command does not implement an authorization allowlist.
Normal completion returns the child status, timeout returns 124, invalid setup
returns 125, and child launch errors return 126/127.

```sh
moon run --target wasm --release commands/timeout -- 1s printf ok
```
