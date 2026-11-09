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

`wget-cookie-dates.json` retains 87 stable Expires controls: 58 original
observations from receipt
`c1148cf940204a2fc7ee9d52e09a5095837f7236cf5789be450c32d2d2a54860`
and 29 additional controls from receipt
`4c2205bcba506d2702e213472e284802bf5efdf0b07eae0178d16aa2c9730169`.
The original frozen expectations have digest
`e918001ceb123a3d9e9da94cde5540606a702318edd1cf3ee68223798aa6bdbf`;
the extra oracle-only expectations have digest
`e73a462316e2350eddcbcc164293a475dc76710ce3e9b53f17e7029852e424c5`.
Extraction preserves the actual oracle rows and row order from each saved file,
with separate source hashes and original labels. Extra labels use `extra-` to
keep the four normal-format controls as independent records. Per-case TZ is
passed to both real execution paths, and no-session cases omit the actual flag.
The fixed executable uses glibc 2.39. Four ordered formats, field-width and ASCII
whitespace edges, the 69 pivot, UTC calendar normalization, timezone suffixes,
epoch -1 ordering and the 127/128-byte boundary have explicit controls. These
expectations do not come from the candidate or establish every libc dialect.

These finite definitions are not execution evidence. The remaining jar behavior,
date-profile extension conditions and Domain-normalization boundaries are in
[ADR-0005](../../../docs/adr/0005-transfer.md).

## Cookie Domain observations

`cookie-domains.json` retains 255 fixed-oracle command records: 120 Curl and
135 Wget. Input bytes, response bytes, actual URL encoding flags, locale,
Host fields, absolute oracle targets and both processes' saved row orders are
independent frozen inputs. Candidate origin-form targets and CONNECT authority
are checked separately; transport framing and jar comment headers are not
claimed byte-identical. The original 16 invalid UTF-8/NUL records are explicitly
excluded and remain unresolved. The corpus retains the four initial Curl
reload failures without changing their expectations. Source receipts and
observation hashes are recorded with each case.
Windows receives the same proxy address in both environment-name spellings,
because its environment is case-insensitive; other platforms retain the
original lowercase-only proxy profile. This adaptation is not a locale or
transport-equivalence claim.
The existing candidate CONNECT line names the destination, while its Host
field names the proxy endpoint. Both are checked explicitly against fixture
inputs; this historical transport behavior is not upstream CONNECT parity.

## Curl Cookie lifecycle and HTTP retries

`curl-cookie-lifecycle.json` contains 20 independently observed controls and
38 actual process phases. Named-file mutation, stdin exhaustion, live response
cookie precedence, expiry cleanup, same input/output paths and saves between
URL operands retain the original requests, complete streams and jar bytes.
Fresh observations added complete file inventories immediately after each
process and were checked against all existing original-oracle observations.
The observer's saved-file copy is represented as a pre-response observation,
not a product-created file. Two deliberately unexecuted reload phases retain
their original reasons; they are not counted as process passes.

`curl-http-retry.json` contains 15 independent controls for complete and
truncated HTTP responses, stdout retention, regular-file reset, directory
output failures, `-f`, exhausted time/count budgets, `--retry-all-errors`, and
522/524 responses. It retains actual arguments, request fields, supplied and
consumed response bytes, complete pre-response inventories and terminal files.
Directory controls include their inner sentinel. Immediate post-write snapshots
in the source records are not assumed to prove child flushing.

Both corpora run through the same real-CLI replay with evidence outside the
product working directory. Missing/extra exchanges, observer errors, incomplete
processes and changed file types or bytes fail acceptance. Linux repeats the
observations against its verified immutable oracle; other platforms run the
frozen candidate contracts. These finite controls do not establish full retry
grammar, disk-full handling, raw invalid-byte Cookie support or publication.
