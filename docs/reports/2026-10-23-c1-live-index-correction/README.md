# C1 live report index classification correction

Status: correction in local validation; C1 acceptance remains pending.
The preceding [remote correction report](../2026-10-23-c1-remote-correction/README.md)
and its exact `b402de6` local evidence remain unchanged.

[PR 43 review 4356716051](https://github.com/moonbit-community/cmd/pull/43#discussion_r4356716051)
identified a mismatch between the documented narrative-report classification
and the selector: editing the existing live report index had a nonempty old
path, so the new-report-only predicate widened it to full.

An ordinary in-place modification of `docs/reports/README.md` now qualifies
for documentation-only scope when both immutable snapshots contain a regular
file at that exact path. Rename, deletion and type changes remain conservative;
a historical report cannot be moved into the index to hide its removal.
The existing narrative-report regression also checks live-index modification
and the historical/type/rename boundaries. This adds assertions without adding
a named test, changing the 1,728-behavior registry or altering dependency graphs.

The extended existing regression reproduced `full != docs` before the fix and
passed afterward. All 42 scope Native tests, the warning-denying scope check
and owned-source formatting passed. An independent read-only review confirmed
the exact old/new path and mode restrictions. Logs are retained as
`/private/tmp/cmd-c1-live-index-{before,after,check,fmt,scope-tests}.log`.

The C1 migration itself remains full/shadow because its selector and shared
verification infrastructure changed. The correction neither activates scoped
execution nor changes a command/core implementation, public API, dependency
coordinate, package version or frozen publication input.

The earlier `b402de6` candidate completed all 20 applicable macOS source steps
and an honest partial audit with no Mac gaps; those reports do not establish
the new correction's execution. Its proposed push request was withdrawn before
any push. The corrected exact commit must receive fresh local reports, retain
missing remote obligations and obtain its own bounded bootstrap authorization
under plan section 15.1. Required PR and actual-main gates remain mandatory.
