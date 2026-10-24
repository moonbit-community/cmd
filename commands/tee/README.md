# tee

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Copy standard input to standard output and each file operand. The observed
`-a`/`--append` path appends instead of truncating files.
`--output-error=warn` reports any failed output and continues the remaining
outputs. `warn-nopipe` ignores closed-pipe errors while retaining regular-file
errors; bare `--output-error` and `-p` select this mode. `exit` stops at the
first output error, while `exit-nopipe` ignores pipe failures and stops for
other errors. An output that failed is disabled, and input consumption stops
when no outputs remain. An open failure in an exit mode occurs before reading
stdin; files already opened remain created or truncated.

The default mode continues after regular-file errors. On a broken output pipe,
GNU normally terminates through SIGPIPE. The released runtime ignores SIGPIPE
and has no public signal-raising API, so this particular default-mode error
returns status 2 with an explicit unsupported-capability diagnostic. It stops
at the same failed sink and preserves earlier output effects. Use `-p` or an
explicit error mode for supported pipe-error handling. Native and Wasm tests
exercise real closed OS pipes and regular files; the Windows error-number
binding is additionally checked by its platform CI.
Windows closed-pipe errors 109 and 232 select the same pipe-error modes. Failed
opens are reported as `Is a directory` only after a public filesystem kind
query confirms the operand is a directory.

`tee` always reads stdin silently until EOF. Terminal, pipe, and redirection
paths do not receive a repository-specific prompt.

## Standalone metadata

Standalone `--version` prints exactly `tee 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: tee`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
