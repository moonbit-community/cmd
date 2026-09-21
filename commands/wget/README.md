# wget

Pure-MoonBit GNU Wget 1.25 HTTP/HTTPS profile, version **0.2.0**. See the
[support record](../../docs/compatibility.md) for platform verification and
exact-version publication evidence.

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
- `--user/--password` and their `--http-*` aliases for Basic authentication,
  sent after a Basic challenge unless `--auth-no-challenge` is selected;
- response cookies shared across redirects and URL operands, Netscape
  `--load-cookies/--save-cookies` jars, `--keep-session-cookies`, and `--no-cookies`.

Default redirect rules remain Wget-specific: POST is rewritten on 301/302/303,
other methods are retained, and 307/308 preserve method and body.

Network authorization belongs to the caller or host. The command does not
embed an allowlist.

This remains a bounded HTTP transfer profile, not full Wget compatibility.
Recursive mirroring, FTP, non-Basic authentication/HSTS, post-download timestamp
restoration, exact GNU progress and diagnostic bytes, and options outside the
documented package help are not claimed.

Cookie matching includes host/domain boundaries, path order, Secure, Max-Age,
Expires, replacement and deletion. Public-suffix database and IDNA behavior
remain project implementation gaps. A challenge cannot replay an already
consumed stdin request body and fails explicitly; file and in-memory bodies
can be replayed. As in GNU Wget, cookie-jar write failures do not change the
transfer exit status; non-quiet runs print a diagnostic.
