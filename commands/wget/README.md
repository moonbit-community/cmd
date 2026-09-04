# wget

Pure-MoonBit GNU Wget 1.25 HTTP/HTTPS profile. The authoritative capability
record is [`docs/compatibility.md`](../../docs/compatibility.md); this README
describes the package-level P1 contract verified by the unified test runner.

The command supports:

- URL operands and repeated `-i/--input-file` lists with blank/comment-line
  handling and aggregate failure status;
- quiet mode, stdout/default/file output, `-o` log replacement, and `-a` log
  append behavior;
- `-c` range resume with safe restart when a server ignores the range, and
  `-N` conditional requests that preserve output after 304;
- repeated `--header`, all documented `--method` values, and explicit-method
  `--body-data` or binary `--body-file` input;
- bounded/unlimited tries, connection-refused and HTTP-status retry controls,
  retry delay, redirect limits, `Content-Disposition`, and numbered filename
  collisions;
- combined/connect/read/inactivity timeouts, certificate verification control,
  environment HTTP CONNECT proxies, and explicit proxy bypass.

Default redirect rules remain Wget-specific: POST is rewritten on 301/302/303,
other methods are retained, and 307/308 preserve method and body.

Network authorization is supplied by the Wasm harness. The command does not
embed an allowlist: the policy suite proves both a denied connection and a
connection allowed only to a local fixture endpoint.

This remains a bounded HTTP transfer profile, not full Wget compatibility.
Recursive mirroring, FTP, authentication/cookies/HSTS, post-download timestamp
restoration, exact GNU progress and diagnostic bytes, and options outside the
documented package help are not claimed.
