# timeout

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Run one command with a millisecond-precise wall-clock limit. Durations accept
plain seconds or `s`, `m`, `h`, and `d` suffixes. A timed-out command is
forcefully cancelled and returns status 124. Process-group termination,
`--kill-after`, and signal selection are intentionally unsupported because the
portable API only provides cancellation for the directly owned child process.
Unlike `sh`, `make`, and `xargs`, this difference from GNU `timeout` keeps the
command behind its compatibility release gate. This package is not in the
default policy allow-list. It is included in the 48-command local build but is
not one of the 47 command modules currently available from Mooncakes;
`moonx cli/timeout` is intentionally unsupported.
