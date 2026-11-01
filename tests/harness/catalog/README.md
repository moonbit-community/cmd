# Test catalog validation

This package validates `tests/cases/index.json` (schema 3) and
`tests/release/policy.json` (schema 1). The former owns stable case IDs,
aliases, executable bindings and platform applicability. The latter owns
package coordinates, releasability, supported options and release selections;
versions come from each command's `moon.mod`.

Validation rejects duplicate or empty identities, invalid selections, unknown
platforms and malformed release policy. Moon discovers package tests directly;
there is no second inventory of individual package-test names.

`tests/cases/generated/quality.json` binds each current JSON case to its source
digest and assertion kind. Generate it with `tests/run.mbtx -- index update`;
`index check` and runtime validation reject stale or incomplete definitions.
The driver validates the whole quality inventory before platform filtering.
Duplicate-stimulus checks preserve argument order, input bytes, fixtures,
environment and timing. Consolidation must preserve original assertions,
aliases and oracle routes.

The [coverage review](../../coverage/README.md) separately binds finite catalog
facets to actual assertions. Index membership, labels and differential equality
alone do not establish local contract coverage or upstream parity.
