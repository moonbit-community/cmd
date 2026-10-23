# Content-bound change scope

This package owns immutable Git inputs, public Moon dependency graph adapters,
automatic impact closure, additive review and schema-v2 freshness. The coverage
package binds those requirements to actual execution. Neither package treats
an impact declaration as passing evidence.

C1 uses the explicit `shadow-full` transition. All existing three-platform
source suites still execute in full. Global selector, audit, workflow and
workspace changes also require current published verification. Scope calculation
does not authorize skipping execution. The trusted-base coordinator and scoped
activation belong to C2.

## Inputs and responsibilities

`git_*.mbt` reads a staged or committed Git tree, including binary/empty blobs,
link text, modes and complete old/new rename/delete/type records. It rejects
unsafe or ambiguous paths, hidden index flags, unmerged entries, nonignored
untracked files and unstaged managed changes. A disposable fresh index prevents
a forged worktree stat cache from hiding an unstaged edit. The real index is
not refreshed as a side effect of verification.

`graph_*.mbt` materializes an owned snapshot and calls the public `moon tree`
module/package JSON interfaces. CI's pinned package-v2 graph is the conservative
union of all declared imports. Package v3 is captured explicitly for Native
and Wasm and normalized to the same identity when the imports agree. Nodes are
selected from the complete workspace graph, including isolated packages.
Wire indices become stable package owners and resolved module coordinates;
test provenance remains distinct from backend applicability. Unknown graph
semantics, unsupported declarations or resolver failures explain a full scope.
They never produce an empty successful graph.

The known `README.md -> README.mbt.md` link is projected to its same-directory,
tracked, regular UTF-8 target in the temporary resolver tree. It never creates
a host symlink and works without Windows symlink privileges. Other symlinks
remain an explicit unresolved/full boundary. Git fingerprints still bind every
original link mode, blob and target byte. Graph resolution is not proof that
a package supports a backend; registry requirements own that responsibility.

`selection*.mbt` unions old/new reverse consumers and separates their forward
build prerequisites. A changed command selects its whole registered collection.
Registry and published rows compare content on both sides. Strictly recognized
literal catalog rows may narrow only with unchanged helper/structure bytes;
unknown expressions use normal core closure. Shared fixtures and child command
launches use `tests/registry/associations.json`; child build prerequisites do
not automatically add unchanged command behaviors. General harness and policy
changes force full. The shared metadata, registry-package execution, network
scenario and mv scenario producers also force full when their own sources or
package manifests change. Their dynamic command launches and shared case /
scenario / publication responsibilities cannot be inferred from imports alone.
Narrow these producer paths only after complete registered consumer and child
artifact associations have equivalent old/new-side regression evidence.
Unknown paths/owners widen; malformed input rejects.

`intent.mbt` and `entry.mbt` own schema parsing, content identities and preparation.
The sole current impact input remains `tests/coverage/ci-change.json`.
`tests/registry/boundaries.json` indexes existing rejection requirements and
their current support/ADR unlock conditions; it is not a second impact list.

## Schema 2

Required top-level fields are `schema`, `transition`, `policy_version`,
`target_ref`, `base`, `payload`, `change_set`, `changes`, `identities`,
`automatic`, `extras`, `selection`, `boundaries`, `deferred` and `uncovered`.
Unknown fields, execution claims, duplicate JSON keys (including escaped
aliases), malformed identities and fractional schemas reject.

`payload` binds all tracked content except the declaration itself. `changes`
and `change_set` bind both path names, full blob IDs, modes and change types;
a rename crossing the declaration path remains bound. Both graph, registry,
association and policy identities are recorded. The self-containing head SHA
is absent; execution receipts bind actual head/merge/run/attempt separately.

`automatic` is the calculated minimum. Each `extras` row supplies a reason and
explicit commands, behaviors, packages or cases plus added requirements.
`selection` retains their union. Requirements keep separate platform/backend/
oracle applicability rather than imposing a global Native/Wasm cross product.
Mapped replacement and rejection tests add actual evidence obligations; they
do not remove the old-side requirement from intent.

Explicit command additions also retain linked non-import integration rows,
using each row's registered requirements. Behavior/case additions and boundary
targets remain targeted; their descriptive command does not select every
ordinary behavior of that command. After additions and boundary mappings,
artifact closure includes their command roots, old/new associated child builds
and forward dependencies. A selected behavior's association membership can
require child artifacts even when no command/path trigger matches. Full or
unresolved associations retain a conservative two-side full selection and
recompute rejection obligations. Required publication rows add their exact
coordinates; build-only children do not imply publication requirements.

Schema 1 can be read as the recorded predecessor during preparation and in
historical first-parent intent inspection. It supplies no schema-v2 automatic
scope or human additions. New change-event verification requires schema 2.
Scheduled/manual full regression derives obligations from current source and
registry without filtering through an old PR declaration.

## Prepare and verify

After finishing code, documentation, registry, interfaces and formatting,
synchronize the target base and stage all intended managed edits. Then run:

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/coverage/prepare_ci_change.mbtx --base-ref origin/main
```

Preparation reads the staged tree, preserves the current branch's reviewed
additions, writes and stages the sole intent, and prints a readable explanation.
A new branch does not inherit the previous mainline change's additions. Review
the declaration and explanation before committing. After committing, run:

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/coverage/audit.mbtx --scope verify --base <exact-base-SHA> --head HEAD
```

Verification requires the clean exact checkout and unchanged intended index.
Local verification also checks the live target ref. Content changes, base
advances, dependency/registry/policy changes or lost additions require another
preparation. Whitespace, timestamps or nonces cannot repair stale content.
The same tree/base with a changed commit message needs no declaration edit.

PR context validation separately checks GitHub's synthetic merge parents.
Main first validates the final saved content and recomputes the actual
first-parent push range, retaining reviewed additions from that range. It
cannot reuse a PR execution receipt. Full/shadow platform receipts bind scope,
source, platform, workflow run and attempt; final coverage checks actual rows
for every selected obligation, including old-side and replacement requirements.

The existing exact-commit coverage push gate remains in force during C1.
`shadow-full` is not a bootstrap or handoff exception. The plan requires a
separate branch/commit-limited authorization if the first policy-migration push
cannot pass the existing gate locally.
