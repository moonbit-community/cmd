# curl

Fetch an HTTP or HTTPS URL through MoonBit's policy-visible HTTP client.
Supports `-s`/`--silent`, `-S`/`--show-error`, `-f`/`--fail`, and
`-o`/`--output`, plus `--idle-timeout SECONDS` (default 30, positive
fractional values accepted). Progress is written to stderr. `-s` suppresses
progress and errors, while `-sS` restores errors without restoring progress.
Progress updates are throttled and use a single terminal status line.
With `-f`, HTTP 400 and later responses fail with the actual status in the
diagnostic. It does not invoke a host `curl` executable; redirects,
uploads, and arbitrary request methods are intentionally outside this first
policy-focused implementation.
