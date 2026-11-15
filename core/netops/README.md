# Network transport

Perform one scoped HTTP exchange using public MoonBit TCP/TLS APIs.

## Usage

Build a `Request` with its target, method, headers and body, then call
`with_response(request, transport, callback)`. Read the response inside the
callback with `ResponseScope::read`; the connection closes on return, error
or cancellation.

| API | Purpose |
| --- | --- |
| parse_absolute_url, resolve_location | Parse targets and resolve redirect locations. |
| Request, Transport | Supply final request fields, body framing, proxy/TLS settings and deadlines. |
| with_response | Open one exchange and run a callback with its response scope. |
| ResponseScope::head, read, sent_bytes | Inspect headers, consume bounded body chunks and observe upload progress. |
| ResponseLine, BodyRead | Preserve raw header/EOF events and exact body-completion boundaries. |
| idna_host, cookie_public_suffix | Normalize hostnames and query the pinned public-suffix data. |

See [the generated interface](pkg.generated.mbti) for signatures and
[exchange tests](exchange_wbtest.mbt) for executable usage.

## Notes

- HTTP/1.0 and HTTP/1.1 support fixed-length, chunked, close-delimited and
  bodyless responses. Content coding is not decoded. Earlier body bytes can
  be delivered before a later framing failure.
- Callers supply the complete request header list, including User-Agent.
  Raw response bytes remain available alongside readable header values.
  Response lines, cumulative headers, field counts and interim responses have
  explicit size/count limits.
- Redirects, retries, authentication, cookies, resume and output commitment
  belong to the curl/wget download packages. This API performs one request.
- A response scope must not escape its callback for later reads.
  Transfer errors retain phase, framing and byte progress; a failed output
  write can have effects that the public writer API cannot count exactly.

See the [compatibility guide](../../docs/compatibility.md) and
[HTTP decisions](../../docs/adr/0005-transfer.md) for the supported profile.
