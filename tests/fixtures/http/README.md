# Local HTTPS fixture

`cert.pem` and `key.pem` are a self-signed localhost certificate pair used
only by the compatibility runner. The private key is test data, not a secret
or a product credential. Product code never shells out to OpenSSL; the native
test harness uses the executable only to expose this fixed certificate through
a local TLS endpoint.

`fixed.txt` is the deterministic body used by the pinned HTTPS oracle cases.
