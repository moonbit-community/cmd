# timeout

Run one command with a millisecond-precise wall-clock limit. Durations accept
plain seconds or `s`, `m`, `h`, and `d` suffixes. A timed-out command is
forcefully cancelled and returns status 124. Process-group termination,
`--kill-after`, and signal selection are intentionally unsupported because the
portable API only provides cancellation for the directly owned child process.
This package is not in the default policy allow-list.
