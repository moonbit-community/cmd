# Phase 2 Pure-MoonBit HTTP and Protocol Feasibility Spike

Date: 2026-09-02

## Decision

The HTTP/HTTPS transfer slice is implementable in pure MoonBit and is now
shared by Wget and curl. It does not call a host executable and does not add
repository C, C++, native stubs, or FFI. The legacy `netops.fetch` API remains
as the Phase 2 rollback point.

The complete Wget and curl commands remain `partial`. This spike records why
the current slice may be delivered without misclassifying the remaining
protocols as impossible.

## Evidence and attempts

The implementation inspected the installed `moonbitlang/async@0.21.0` public
surface with `moon ide` and dependency source:

- `@http.Client` exposes HTTP/HTTPS connections, request/response streaming,
  standard request methods, headers, CONNECT proxy tunnels, and TLS trust
  selection.
- `@socket.Addr::resolve`, `@socket.Tcp::connect`, async readers/writers, and
  `@tls.Tls::client` expose the primitives needed for direct line/binary
  protocols without host delegation.
- `@fs` exposes reads, writes, append/truncate, size, and mtime reads, but no
  public portable setter for a downloaded file's mtime.
- The public HTTP request method is a closed enum containing GET, HEAD, POST,
  PUT, DELETE, CONNECT, OPTIONS, TRACE, and PATCH. It cannot serialize an
  arbitrary extension token. The HTTP response exposes status, reason and a
  normalized header map, not the raw HTTP version/header byte sequence.
- Public async timers accept a signed `Int` millisecond duration. The command
  adapters reject values above that range before network side effects and
  state the bound in help/README; representing multi-week single-phase timers
  would require a separately reviewed deadline/cancellation design.

Direct pure-MoonBit designs were then evaluated:

| Family | Pure-MoonBit design | Current result |
| --- | --- | --- |
| HTTP/HTTPS | Repository URL parser and RFC 3986 resolver over `@http.Client`; stream request files/stdin and response files/stdout; close every redirect hop. | Implemented and covered by local state-machine and pinned quiet-oracle fixtures. |
| HTTP proxy/TLS | Use public CONNECT-proxy client and `SystemRoot`/`NoVerification`; preserve command-specific proxy bypass rules. | Implemented in the measured HTTP slice. A pure-MoonBit CONNECT relay fixture verifies proxy transport, and a pinned self-signed certificate fixture verifies default rejection plus curl `-k`/Wget `--no-check-certificate` on Unix CI. |
| FTP/FTPS | Implement RFC 959 control replies, PASV/EPSV data connections, TYPE, RETR/STOR, REST and TLS upgrade over public TCP/TLS APIs. | Technically feasible; not attempted as production code in Phase 2 because it is an independent protocol/state-machine workstream, not because MoonBit is blocked. |
| SFTP/SCP | Implement SSH transport, key exchange, host-key validation, user authentication, channel multiplexing and SFTP packets, or adopt an audited pure-MoonBit SSH package. | No suitable pure-MoonBit dependency was present in the locked workspace. Public TCP/crypto primitives do not provide SSH semantics; implementing and auditing SSH is a separate security project. No permanent exception is accepted here. |
| SMTP/SMTPS | Direct command/reply state machine with EHLO, STARTTLS, AUTH, DATA framing and dot-stuffing over TCP/TLS. | Technically feasible; remains an unimplemented protocol workstream. |
| IMAP/IMAPS and POP3/POP3S | Tagged/line reply parsers, literal framing, STARTTLS and authentication over TCP/TLS. | Technically feasible; remains an unimplemented protocol workstream. |
| LDAP/LDAPS | BER codec plus LDAP message state machine over TCP/TLS. | Technically feasible but needs a separately reviewed BER/security implementation. |
| SMB and TELNET/TFTP/GOPHER/DICT/MQTT | Protocol-specific framing/state machines over TCP or UDP, plus authentication/security where applicable. | Public socket primitives are sufficient for feasibility; each remains unimplemented and requires its own oracle and threat review. |

Target-conditioned pure-MoonBit code does not remove the two HTTP API gaps:
arbitrary methods and raw response headers are absent from the public interface
on both Native and Wasm. Reimplementing all HTTP framing on raw sockets would
recover those two details, but would duplicate proxy, TLS, decompression and
HTTP parsing and create a larger correctness/security surface. Phase 2 rejects
unsupported methods explicitly and labels `-I` raw-byte parity as unmeasured;
it does not claim those gaps are permanent exceptions.

## Observable boundaries

- Supported HTTP/HTTPS operations fail before output creation when URL,
  method, header, proxy or TLS setup validation fails.
- Wget HTTP status failures use status 8; curl `-f` failures use status 22.
- Redirect loops and limits close the current client before returning an error.
- Authorization, proxy authorization and cookies are removed on cross-origin
  redirects; a local two-origin fixture proves the behavior.
- A fixed-length response that ends early fails, and
  `--remove-on-error` removes the partial destination.
- Wget `-N` can issue `If-Modified-Since` and preserve a 304 destination, but
  cannot yet restore the server's `Last-Modified` time after a 200 response
  because no public portable mtime setter was found. This remains an open
  implementation/capability item, not a silent compatibility claim.

## Follow-up gate

Before any non-HTTP family changes from “unimplemented” to an accepted
exception, its own spike must provide a minimal server, protocol transcript,
public-API and pure-dependency search, Native/Wasm classification, safe
no-side-effect failure, and a pinned upstream curl/Wget comparison. Until then,
help, README and the compatibility matrix keep both commands `partial`.
