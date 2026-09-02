# Internal network helpers

This package contains the shared HTTP streaming path for `curl` and `wget`.
It does not invoke a host network executable. Network access remains visible
to the configured network policy.

The `transfer` state machine parses HTTP/HTTPS URLs without using private
runtime APIs, resolves relative redirects according to RFC 3986, closes every
hop, detects loops, strips sensitive headers across origins, and streams both
request and response bodies. Connection setup, request writes, response
headers, and each response read have separate inactivity checks; a successful
chunk resets the phase timer, while an optional total deadline spans all
redirects. Premature fixed-length EOF is an error.

Destinations support stdout, discard, truncate, append/resume, numbered
collision files, `Content-Disposition`, 304 preservation, and optional cleanup
after a partial transfer. `TransferErrorKind` separates URL, protocol, proxy,
TLS, timeout, HTTP status, input, and output failures so Wget and curl can keep
their distinct exit statuses and diagnostics. Progress events carry status,
headers, known length, and received bytes; commands decide whether and how to
render them.

The legacy `fetch` and `fetch_with_options` entry points remain source
compatible and retain the original 30-second default. New command adapters use
`transfer_options` directly.
