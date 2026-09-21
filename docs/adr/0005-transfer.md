# ADR-0005: Pure MoonBit HTTP Transfer Profile

Status: Accepted
Date: 2026-09-05
Updated: 2026-09-21
Revision: Include Basic auth and cookies; share candidate and fixed-oracle network scenarios.

## Target and decision

Implement curl/wget HTTP/HTTPS with public async APIs. Basic auth, cookie selection/persistence and redirect state are project responsibilities. async 0.22.1 Response.cookies exposes repeated Set-Cookie separately from the header map. Preserve command-specific credential challenge/redirect rules and cookie domain/path/Secure/expiry behavior within the documented subset.

## Alternatives and compatibility cost

Reject host curl/wget delegation, own FFI and permanent exclusion of implementable protocol state. Do not forward authorization blindly across origins. Basic auth tests do not imply all protocols, authentication mechanisms, browser cookie policy or exact progress bytes.

## Versions and evidence

Custom `Cookie:` request headers combined with matching jar cookies require
duplicate request fields, which the public HTTP request map cannot represent.
Reject that combination before sending it; do not silently merge or discard
fields. Reopen when a public ordered header-list API is released. Literal curl
`-b` cookies and custom Cookie headers are restricted to the initial origin;
stored jar cookies are selected for the redirect destination. The pinned curl
8.22.0 Linux oracle removed literal cookies on a cross-host redirect, unlike
the older macOS probe. The fixed-version oracle defines the current contract.
PSL/IDNA and cookie
prefix rules remain project work rather than async limitations.

Baseline: async 0.22.1, x 0.5.5, moonjq 0.1.2; MoonBit 2026-09-15.
Command option tests, core/netops cookie tests and `network-auth-cookie` exercise the implemented profile against loopback HTTP fixtures. `network-auth-cookie-oracle` preserves the old probe's live output/status and jar-mode comparisons against the pinned Linux oracle. Its implementation and CI registration are not a local Linux pass. The original probe remains archived. Only final passing options are promoted in the support record.
Historical results remain in [the audit](../reports/2026-09-19-command-fidelity-audit.md).
Candidate runtime results are recorded separately from published versions.

## Revisit when

Extend additional protocol/auth/cookie behavior with direct upstream fixtures; new APIs alone are not evidence of implemented behavior.
