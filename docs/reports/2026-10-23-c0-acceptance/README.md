# C0 actual-main acceptance

Recorded on 2026-10-23 after the investigation report's recorded pending state.
The [investigation](../2026-10-23-c0-investigation/README.md) remains unchanged.

PR [#42](https://github.com/moonbit-community/cmd/pull/42) merged candidate
`82ba94b01f5a4cf4e91789d73158caa87cc8a261` into actual main
`4180e527b8673e51dc0127d1747e27f2b3b7e95c`. The merge tree is
`a7605617a85d44c20eede7cf2a6a266a13c3a956`, with parents
`5fef93ecec8cebeb7b4f9bdd479e8f3619d12513` and the candidate above.

[Actual-main run 39888307225](https://github.com/moonbit-community/cmd/actions/runs/39888307225)
attempt 1 passed `ubuntu-24.04`, `macos-15`, `windows-2025` and
`coverage-audit`. The audit used the actual push range `5fef93e..4180e527`,
bound 35 execution reports and reported no findings, uncovered, unsupported,
boundary or deferred items for this harness change.

The coverage artifact is GitHub artifact `12474921766`, SHA-256
`1bd595be8f74a18d198f5b71445f30012d6de5045b47e592d105f4758d2396df`.
The downloaded bytes match the service digest and ZIP CRC checks. The local
evidence directory is
`/private/tmp/cmd-c0-remote-evidence-2026-10-23/actual-main-4180e527/`:
run/jobs/artifact metadata, four full job logs and the extracted audit are
retained. Remaining complete platform artifacts have recorded service IDs and
digests rather than duplicate local copies.

The corrected PR run
[39884395795](https://github.com/moonbit-community/cmd/actions/runs/39884395795)
also passed all four required checks at synthetic merge
`fec5d232125f5b73152849eec9a784dbe2984235`. It is additional PR evidence;
actual-main acceptance above is the C0 exit condition.

The original failed main run's failed-job rerun, attempt 2 of
[39438523360](https://github.com/moonbit-community/cmd/actions/runs/39438523360),
also passed its original exact range and historical oracle identity. The
historical empty-stdin hexdump timeout's cause remains unconfirmed. The
independently reproduced Docker orphan cleanup defect was repaired and tested;
neither a successful rerun nor that distinct defect proves the timeout's cause.

C0 changes no command/core source behavior, package version or published
coordinate. C1 may start in full/shadow mode. Later feature, performance,
publication and issue-closure gates remain pending.
