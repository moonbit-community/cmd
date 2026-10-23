# C1 shared producer and addition closure

Status: correction under local validation; C1 acceptance remains pending.
Earlier exact-source reports remain unchanged.

The separately authorized `1dee483418cf731aad9d74ae1b1d862403df8803`
push started [PR run 39940396515](https://github.com/moonbit-community/cmd/actions/runs/39940396515).
Its synthetic checkout is `02c594fffb27fb0c7ed17066b3b11aea26b07d00`,
with parents main `4180e527` and that head; tree
`7122b43897bc2d1d07020c5020289734238d9adf` matches the frozen candidate.
Actual Windows global tests passed Native 593, Wasm 287, JS two and Wasm GC
two. This proves the preceding fixture-path correction in real Windows CI;
it does not validate a later source revision or complete C1 acceptance.

All four required checks subsequently passed for that exact earlier checkout.
Its coverage proof selected 1,728 behaviors and bound 37 actual runs, with zero
findings, uncovered or deferred obligations. Its independent frozen-publication
proof passed all 1,028 selected cases and 78 exact coordinates. Coverage
artifact `12497826788` is 11,912 bytes, SHA-256
`2b42a1ab1297da683741754dc7aa01761844c37ab117bbe90135146d8ec4362d`;
downloaded bytes match the service digest and every ZIP CRC passed. These
earlier full-run results do not resolve the selector-foundation gaps below,
authorize a later push or establish actual-main acceptance.

## Shared producer closure

Supplementary peer review found four producer paths whose import/owner closure
was not their complete execution dependency:

- `tests/metadata/` enumerates metadata rows and launches command artifacts;
  selecting its own package could omit those command build roots.
- `tests/packages/` executes registered command/core tests dynamically;
  its own package tests do not represent every protocol consumer.
- `tests/mv_scenarios/` launches command children not represented by its
  import graph.
- `tests/network_scenarios/` serves source and published execution. Existing
  associations selected typed scenarios and child builds, but could omit the
  associated raw case rows and publication coordinates.

These four shared producer prefixes now force full scope. Existing non-import
associations and separate child build prerequisites remain in force for
ordinary command changes. Narrow these producer paths only after complete
old/new consumer, child artifact and raw/typed/publication associations have
equivalent regression and execution evidence.

The existing shared-harness named regression now uses known package owners
and helper/manifest paths, so unknown-path fallback cannot make it pass. It
checks every command and ordinary behavior, both raw and typed network rows,
child/core build prerequisites, exact publication coordinates and unchanged
Windows-only boundary applicability. No new named test or registry entry was
created. The valid pre-fix run failed with `scoped != full` (41/42 passed);
after the four-prefix correction all 42 scope tests passed. Logs:
`/private/tmp/cmd-c1-shared-harness-before-fix-valid.log` and
`/private/tmp/cmd-c1-shared-harness-after-fix.log`.

## Reviewed additions

A related review found that post-selection additions and boundary mappings
need their own command and non-import child artifact closure. Explicit command
additions now retain linked integration rows with each row's own registered
requirements. Targeted behavior/case and mapped rejection/replacement rows
remain targeted; child builds do not imply every ordinary behavior of the
unchanged child command.

Final artifact roots include selected packages, command roots and matched
old/new child builds. Association membership can require child artifacts even
without a matching command/path trigger. Wildcards include both inventories,
including an old local-only command; forward closure retains removed old-side
edges. Full rules widen conservatively and recompute newly selected rejection
obligations. A required published-differential row contributes its exact
coordinate even when its command was not promoted to a whole ordinary command
collection. The automatic floor is preserved separately.

The existing freshness/human-addition regression checks these cases through
the actual intent constructor. It preserves independent old/new platform and
backend requirements and verifies that extra evidence strengthens only explicit
targets. No named test, import or public API was added. All 42 scope tests and
52 coverage tests passed after the combined correction. Targeted logs are
`/private/tmp/cmd-c1-closure-{scope,coverage}-tests.log`; the all-target warning
check passed at `/private/tmp/cmd-c1-closure-check.log` with the documented
host `--no-mbti` adaptation.

The independent follow-up review also required the missing-association guard
after reviewed additions. A selected scenario/cohort/policy row without a
registered association has unknown child coupling, including an aggregate row
whose command is `all`. It now widens to full rather than accepting a scoped
result. The valid negative first reproduced `scoped != full` (41/42 passed);
after correction all 42 scope tests passed. Logs are
`/private/tmp/cmd-c1-missing-association-{before,after}-fix.log`.
The shared integration-kind predicate is reused by automatic selection and
the reviewed-addition floor. Registry source/ownership tests also passed 33/33
at `/private/tmp/cmd-c1-closure-registry-tests.log`.

No command/core implementation, public API, version or frozen published input
is changed by the shared producer correction. Current `shadow-full` CI still
builds and executes all suites, so the reviewed selector gaps did not remove
execution from the earlier full run. The corrected exact commit must receive
fresh local validation, an honest partial audit and its own plan-section-15.1
bounded push authorization before remote verification. Required three-platform,
coverage, actual-main and publication gates remain unchanged.
