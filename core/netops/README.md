# Internal network helpers

This package contains the shared HTTP streaming path for `curl` and `wget`.
It does not invoke a host network executable. Network access remains visible
to the configured network policy.

The configured fetch path applies an inactivity timeout to request setup,
response headers, and every body read. Receiving a body chunk resets the
timer. It streams directly to stdout or a destination file, checks HTTP status
before creating a successful output file, and reports byte or
`Content-Length` progress on a configured diagnostic destination. Feedback is
explicitly selected as `Quiet`, `ErrorsOnly`, `Progress`, or `Summary`;
interactive progress is detected once per fetch and refreshed at most every
100ms. The legacy `fetch` function remains available with a 30-second timeout
and its original no-progress behavior.
