# curl

Fetch an HTTP or HTTPS URL through MoonBit's policy-visible HTTP client.
Supports `-s`/`--silent`, `-S`/`--show-error`, `-f`/`--fail`, and
`-o`/`--output`. It does not invoke a host `curl` executable; redirects,
uploads, and arbitrary request methods are intentionally outside this first
policy-focused implementation.
