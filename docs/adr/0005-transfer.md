# ADR-0005: Pure MoonBit HTTP Transfer Profile

Status: Accepted
Date: 2026-09-05
Updated: 2026-09-21
Revision: Use both public HTTP header layers for curl's explicit-plus-jar Cookie fields; preserve Wget's explicit Cookie override and command-specific credential scopes.

## Target and decision

Implement curl/wget HTTP/HTTPS with public async APIs. Basic auth, cookie selection/persistence and redirect state are project responsibilities. async 0.22.1 Response.cookies exposes repeated Set-Cookie separately from the header map. Preserve command-specific credential challenge/redirect rules and cookie domain/path/Secure/expiry behavior within the documented subset.

## Alternatives and compatibility cost

Reject host curl/wget delegation, own FFI and permanent exclusion of implementable protocol state. Explicit Basic credentials use a command-specific scope: the public transport defaults to the initial origin, while Wget selects all origins for `--user/--password`. Custom authorization headers retain their separate redirect behavior. Applying curl's scope to Wget was rejected because it changes authenticated redirects despite the caller supplying explicit credentials. Basic auth tests do not imply all protocols, authentication mechanisms, browser cookie policy or exact progress bytes.

## Versions and evidence

The fixed GNU Wget 1.25.0 Linux oracle in CI run `35575026875` sends
`--user/--password --auth-no-challenge` credentials through a redirect from
`127.0.0.1` to `localhost`; the previous candidate incorrectly omitted them.
The [GNU Wget manual](https://www.gnu.org/software/wget/manual/html_node/HTTP-Options.html)
defines preemptive Basic authentication for all requests. Without that option,
each previously unchallenged origin must issue its own Basic challenge before
explicit credentials are sent. The transport keeps challenge state per origin,
so one server's challenge does not enable unsolicited authentication to another.
Core HTTP fixture regressions cover default origin restriction, Wget preemptive
redirects, and challenge-driven redirects. Their execution results are recorded
by the release validation; registration alone is not a pass. Additional host,
port or authentication-cache behavior requires a fixed upstream fixture before
expanding this profile.
The [Wget 1.25.0 implementation](https://git.savannah.gnu.org/cgit/wget.git/tree/src/http.c?h=v1.25.0)
selects global command-line credentials again for each URL and caches Basic
challenges by hostname. This implementation currently caches them per origin
within a transfer. Reusing a challenge across ports or separate URL operands is
not yet claimed; adding a shared command-session authentication cache requires
specific upstream comparison cases. Credentials can still answer a new Basic
challenge at each allowed origin.

The current workspace sends matching jar cookies through persistent client headers
and an explicit curl `Cookie:` through per-request headers. async 0.22.1 emits
these separately and in that order. Wget selects `ReplaceStored` so its explicit
field replaces outgoing jar cookies without disabling response-cookie storage.
Wget also forwards that explicit field across origins, as its 1.25.0 wire probe
shows; curl removes it. An independent `custom_cookie_cross_origin` flag preserves
this difference without changing Basic or custom Authorization handling.
The earlier single-map rejection was too restrictive. A pure MoonBit raw TCP
probe confirmed the public API path and compared curl 8.7.1 and Wget 1.25.0;
core tests assert the wire fields and redirect behavior, and the shared CLI
scenario compares against pinned Linux tools when its oracle suite runs.
Reject CRLF injection, concatenating fields, or maintaining a second HTTP stack:
none is needed for this case. The compatibility cost is limited to unsupported
arbitrary ordered repeated headers: two maps do not replace an ordered list.
That remaining limit can be lifted by a public list API plus wire-level tests.
These corrections are local candidate changes, not changes to published 0.2.0.
Literal curl
`-b` cookies and custom Cookie headers are restricted to the initial origin;
stored jar cookies are selected for the redirect destination. The pinned curl
8.22.0 Linux oracle removed literal cookies on a cross-host redirect, unlike
the older macOS probe. The fixed-version oracle defines the current contract.
PSL/IDNA and cookie
prefix rules remain project work rather than async limitations.

Recheck baseline: async 0.22.1, x 0.5.5, moonjq 0.1.2; MoonBit 2026-09-20,
moonc 0.10.14+7d59c7ec9. The original 0.2.0 release used the earlier pinned toolchain.
Command option tests, core/netops cookie tests and `network-auth-cookie` exercise the implemented profile against loopback HTTP fixtures. `network-auth-cookie-oracle` preserves the old probe's live output/status and jar-mode comparisons against the pinned Linux oracle. Its implementation and CI registration are not a local Linux pass. The original probe remains archived. Only final passing options are promoted in the support record.
Historical results remain in [the audit](../reports/2026-09-19-command-fidelity-audit.md).
Candidate runtime results are recorded separately from published versions.

## Revisit when

Extend additional protocol/auth/cookie behavior with direct upstream fixtures; new APIs alone are not evidence of implemented behavior.
