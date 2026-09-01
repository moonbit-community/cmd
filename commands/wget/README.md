# wget

Download an HTTP or HTTPS URL through MoonBit's policy-visible HTTP client.
Supports `-q`/`--quiet`, `-O`/`--output-document`, `-o`/`--output-file`, and
`--idle-timeout SECONDS` (default 30, positive fractional values accepted).
Downloads show progress on stderr; `-q` suppresses progress and summaries.
Errors remain available in `-q` mode unless `-o FILE` routes them to a log.
Progress updates are throttled and use a single terminal status line. With
`-o FILE`, all progress and failure diagnostics are written to `FILE` and
stderr remains untouched.
HTTP 400 and later responses fail without creating a successful output file.
`-O -` streams the response body to stdout.
It does not invoke a host `wget` executable; recursive downloads, headers,
uploads, and certificate bypasses are intentionally unsupported.
