# Reviewed stage-0 CI impact

Base: `5c2f93e` (resolved to its exact commit by the audit workflow).

This candidate upgrades the released async dependency from 0.22.4 to 0.22.5
through core, all 79 command modules and the test harness. Compiler integer
type adjustments, dependency resolution, candidate metadata and existing
public behavior are part of this range. The reviewed scope includes every
registered command/core behavior, metadata probe, command scenario,
semantic compatibility cohort and policy check. The retained `cohort:gnu-host`
is excluded from acceptance impact: it is a host-PATH supplementary diagnostic,
not an admissible sealed-oracle result. Its registry entry remains unchanged;
all eight related commands retain their contract, backend-pair and immutable
upstream requirements. Existing registry requirements are
preserved, including Native/Wasm pairs, immutable upstream differentials and
explicit rejection evidence. The global requirement arrays are empty because
each registry entry owns its applicable backends and evidence; a Native-only
harness test or Windows Wasm boundary must not acquire a fictitious second
backend requirement.

The manifest invariant checks all 81 module declarations and workspace
membership, including the six commands that do not depend on core. Minimal
local-core workspace checks, if collected, are development evidence. Exact
standalone registry resolution and published-consumer parity for the intentionally
unpublished core 0.7.0 remain centralized-release acceptance; this declaration
does not assert either outcome or require early publication.

The new transfer cases require exact successful fixed/empty/chunk/trailer/
close-delimited controls on both command backends and the sealed Linux oracle.
Separate stateful command scenarios cover premature/malformed responses,
partial stdout/files, remove-on-error, retries, Range requests, aggregate `-O`
and selected output-name reuse. Their ordinary contract and upstream comparison
registrations are distinct. Package tests independently exercise the shared
error model and resumed-output validation. The new pure MoonBit HTTP/1 adapter
uses the existing public passthrough API, distinguishes empty/incomplete headers
and exposes chunk payload before later framing checks. Native/Wasm wire tests
cover informational responses, separate Set-Cookie fields, exact upload bytes,
request/header phases and metadata-limit rejection effects. Those limits are
64 KiB per protocol line, 1 MiB cumulative headers, 1024 fields per block, 128
interim responses and 1024 trailer fields. These changes remain subject to the
same command and immutable-oracle evidence; no fixture label establishes
parity. Proxy CONNECT diagnostics and ordinary repeated request-header option
semantics remain project work, not unavailable byte APIs. Wget continued GET with
Content-Disposition now requires HEAD discovery before selecting the destination
and its resume offset. Observe request order, selected-name reuse and both file
paths; the lower-level transfer still rejects a direct resumed switch to a
different destination.

The generated-header regression requires zero request bytes on a real TCP
connection and preserved file contents; the curl input-validation case separately
requires status 2, its exact diagnostic and no output file. This is not an
upstream-parity or missing-capability claim. The cancellation test observes a
real file closed by the same private sink scope used in transfer and verifies
that repeated close cannot close a subsequently opened file. Buffered-tail and
remove-on-error cancellation behavior remain part of the resource stage.

The wire-review correction retains all existing impact requirements and adds
command-specific request-target and response-cookie observations. Initial raw
ASCII space/TAB/CR/LF/DEL in path/query must produce curl 3 before connecting
and preserve an existing destination; Wget must emit uppercase percent escapes.
Encoded controls remain encoded. Followed Location space/TAB controls require
curl path `%20`/query `+` and TAB `%09`, versus Wget `%20`/`%09` in both
components. Observe actual request bytes and connection counts, not only status.
Final response Set-Cookie fields retain names, values and order independently
of cookie storage, with HTTP optional whitespace normalized and interim fields
excluded. Missing `=` must not fail a complete body; nonnumeric Max-Age must
delete the matching curl cookie while preserving Wget's prior cookie. Positive
decimal overflow requires the opposite replacement effects: curl keeps the new
cookie under its 400-day cap, while Wget expires matching cookies for numeric
overflow below 32 digits. Fixed-clock tests cover the cap, rounding and overflow
boundaries. Subsequent request bytes must distinguish profile-specific cookie
ordering and preserved creation order. Repeated-field order requires request
and jar-state observations, without claiming byte-for-byte jar serialization.
The fixed comparisons establish expectations only; new registered package,
command, Native/Wasm pair and immutable-oracle evidence must use the repaired
exact source. Earlier CI runs cannot establish acceptance for these changes.

The transfer declaration includes the public strict/curl/Wget profiles and
their different observable results. Preserve strict default rejection controls
alongside the command-specific 200 header-EOF acceptance, Wget chunk-payload
and trailer EOF acceptance, Wget 416 transfer-output preservation, wrong-Range failure
and complete shorter known-length 200 resume behavior. Curl file cases must observe delayed
opening, the 4096-byte buffering boundary, retained tail bytes and the order of
network and output failures. A failed secondary flush records uncertain file
effects without replacing an earlier network failure. Ordinary unopened
destinations remain unchanged after an initial empty failure, including with
remove-on-error. Curl retries additionally require filesystem observations
before the next response: an accepted retry resets an already opened regular
file to empty, and remove-on-error removes an opened selected file only after
final failure. A valid `-O -J` filename on a 2xx/3xx response creates exclusively before body delivery;
an existing selected filename returns 23 unchanged. Retries keep the first
server-selected filename when later headers change or omit it. Observe final
failure, successful retry and absent/existing controls independently. These
curl-specific lifecycle corrections do not alter strict or Wget profiles.
Status-selection controls include 200/304 and 404/500: the latter ignore
Content-Disposition and retain ordinary lazy output, while `-f` returns 22
without creating a transfer file. Fixed status probes supply expectations only.
Path-based reset uses released open operations but does not claim descriptor or
inode identity under concurrent pathname replacement; that remains the narrower
[#10](https://github.com/moonbit-community/cmd/issues/10) boundary. Fixed-oracle
probes establish expectations, not candidate Native/Wasm acceptance.
Wget's explicit aggregate
`-O` file initialization occurs before requests and requires separate effects
from the shared 416 path. File buffering does not claim
stdout parity. Wget does not retry stdin; curl retry-all may send an empty body
after consuming stdin, as observed in the fixed oracle. The `-sS` retry case
also requires the exact intermediate missing-byte diagnostic despite eventual
success; ordinary silent retries retain empty stderr. Redirect-required rewind
after nonempty stdin upload maps to curl 65, with an empty-body control;
authentication behavior requires independent cases. Package contracts, real command
files and fixed-oracle wire/status observations remain separate evidence.

Windows link fixtures distinguish forced file/directory symbolic links from
junctions. POSIX move cases require independent upstream comparison. Windows
no-clobber contracts preserve links and referents on both backends. Dedicated
Windows command scenarios separately require Native rename effects and Wasm
rejection before mutation; their registered backends are Native and Wasm,
respectively. Both execute the currently allowed regular-source replacement of
destination links without backup. Wasm also requires interactive refusal with
stdin held open, observed exit before closing it, no prompt, and an unchanged
complete snapshot. The Windows-only rollback package test observes completed
Native link/junction backups before fault injection and independently checks
restored link type, target and referents; Wasm must reject before injection.
Scenario option tags name only their executed CLI rounds; `--update=none`
retains its existing package regression without a claim that these scenarios
execute it. No timestamp-based `-u` link-skip acceptance is claimed. The Wasm case and scenario require passing rejection rows,
ADR-0004, the current support record and the issue #38 host-fix
unlock condition. They are not backend-pair claims. The junction and link-backup
package-test exceptions exclude non-Windows hosts only. Missing Windows creation privileges
or PowerShell link observations are infrastructure failures; a macOS package
test cannot establish the Windows result.

Eight existing POSIX oracle cases now explicitly request their missing metadata
observations. The five `ln` force/backup/target-directory/no-dereference cases and
the two async 0.22.5 `mv` symbolic-link cases require `symlink-target`; the `mv`
hard-link no-op case requires `mode` and `identity`. Acceptance requires these
dimensions in the actual snapshots and strict candidate/oracle comparison on
both Native and Wasm. Content/type snapshots and successful status alone do
not satisfy those requirements. Existing file assertions, registry requirements
and the full reviewed impact remain unchanged.

Harness bindings name the affected tests for each changed source: raw wire
framing and Range fixtures, Windows observer parsing, source/registry integrity,
scenario report/pair identity, and release selection. These tests supplement
the actual command scenarios and their filesystem/network observations. No
single generic harness test substitutes for all changed harness behavior.
The open-stdin observation regression rejects deadline, cleanup and missing-exit
failures independently; existing runner helper processes exercise the actual
observer before Windows interactive rejection rounds.
Default scenario selection consumes registered backend requirements; an
explicit wrong-backend selection retains its diagnostic skip. The auditor's
requirements and rejection of applicable skips remain unchanged.

Existing rejection profiles remain registered and retain their command support
records, canonical ADRs and unlock conditions. The async update adds no public
filesystem identity, metadata setter, readlink, terminal or process-observation
capability. A dependency bump does not close those boundaries.

The published baseline remains core 0.6.0 and 78 published commands; timeout
remains local-only. Candidate generation reads the new source versions without
rewriting frozen published manifests or historical evidence. The CI declaration
contains impact and requirements only, with no reports, result labels or
assumed passes. Acceptance needs clean exact-head evidence, all applicable
Linux/macOS/Windows jobs, the immutable Linux oracle and the coverage audit.

## Production import admission

The complete change range also includes a harness-only admission correction.
The policy scanner excludes an import block from production authority only
after its closing scope explicitly identifies test or wbtest. Package aliases
do not change authority: production imports of moonbitlang/async/process,
cli/core/process and cli/core/shell remain rejected for non-restricted commands.
Unknown scopes, mixed scope suffixes, incomplete blocks and unsupported import
syntax fail admission. No product import, command tier or host policy is relaxed.

Four named Native harness regressions cover multiple production/test blocks,
aliases, malformed scopes and separators, escaped paths, actual comments, and
the current mv test-observer manifest. They are required on every applicable
platform and are explicitly bound to policy.mbt; runner documentation also
retains that binding. These harness checks supplement the existing Wasm policy
execution. All 79 affected commands, Native/Wasm evidence, immutable oracle
requirements and actual Windows link/referent evidence remain required.

The cookie scenario's control file requests the same `0666` creation mode as
the jar before comparing real `stat` observations. Its registered
`network-auth-cookie` contract/pair and `network-auth-cookie-oracle`
differential remain required on their declared backends. Fixed-oracle runs
must use the image's `022` creation mask and preserve command `argv[0]` across
any emulator; correcting the test environment does not authorize altered
output bytes, post-creation chmod or weaker filesystem comparisons.
