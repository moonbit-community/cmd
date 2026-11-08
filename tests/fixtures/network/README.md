# Fixed network expectations

`wget-authentication.json` retains 73 independently observed Wget 1.25.0
credential/challenge/cache controls. The original 47-case baseline and 26-case
supplement are hash-bound in the file. Expectations use actual oracle results;
the source-predicted successful custom-Authorization outcomes were disproved
and are not used. Both Basic and Bearer custom fields survive challenge retries.
Every invocation preserves a sentinel and binary `body.bin` input. Two controls
reopen and replay its exact bytes `000102414243ff0d0a` across authentication.
The corpus distinguishes no password from an empty password and records
no-network errors for empty URL usernames and invalid attached booleans.
Configuration, netrc, non-Basic schemes and general URL grammar remain outside
this finite profile. Its oracle arguments explicitly disable config and netrc.

`wget-cookies.json` retains 58 finite cookie expectations observed independently
with GNU Wget 1.25.0 from source archive SHA256
`766e48423e79359ea31e41db9e5c289675947a7fcf2efdcedb726ac9d0da3784`.
The corpus records its immutable diagnostic image and original observation digest.
Its expectations came from the fixed upstream executable, not the candidate.
One initial proposed expectation was corrected from the actual wire: quoted
values followed by junk are truncated at the closing quote, not rejected.

The current scenario executes candidate Wasm and, separately on Linux, the
repository's sealed oracle profile. Every case observes two processes: the
original URL sequence saves a jar, then another process loads that saved jar.
Exact request Cookie fields, logical jar rows, status/streams and untouched
input/sentinel files are required. Missing data or an empty selection fails.
Jar comments contain tool-specific timestamps and are outside row comparison.
The duplicate-path representative control additionally pins the original row
order in both saved files and observes different initial/reloaded Cookie order.
Its supplemental immutable-oracle observation digest is retained in the corpus.

`wget-cookie-expiry.json` retains 194 stable numeric-expiry controls. The first
103 were mechanically extracted from the frozen independent Wget receipt
`c96827d584807314bbb65deed07d0d7cd5215755893fe9a7d26127f5151dea7a`.
The intermediate extraction digest is
`8e3e7b9e6e84e165f9e3d49618f9688d1d63681ab076b1bad1a340f5f100b3e5`;
91 additional controls come from the separately frozen extraction
`b05f0d18524d507b8b72762ab9be5fe4a6998c2c6dc091f90bc031df8e2a9935`,
including the independently discovered `0x.` empty hexadecimal significand
rule, infinity prefixes and hexadecimal rounding boundaries. Each record also
keeps its original oracle observation digest. No candidate output supplies
expected values. Both phases' sorted rows and actual row order
are retained, including cases without session-cookie saving. The excluded IDs
name current-second, relative-future and dynamic addition probes whose real
observations need independently measured time intervals. Private fixed-clock
tests cover their state transitions without replacing those timing receipts.
The local diagnostic profile fixes Linux/amd64 conversion behavior; it does not
establish portable C semantics for out-of-range floating conversion.

These finite definitions are not execution evidence. The outstanding date,
remaining jar behavior and Domain-normalization boundaries are in
[ADR-0005](../../../docs/adr/0005-transfer.md).
