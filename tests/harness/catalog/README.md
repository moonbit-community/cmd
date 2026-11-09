# Test catalog validation

This package validates `tests/cases/index.json` (schema 3) and
`tests/release/policy.json` (schema 1). The former owns stable case IDs,
aliases, executable bindings and platform applicability. The latter owns
package coordinates, releasability, supported options and release selections;
versions come from each command's `moon.mod`.

Validation rejects duplicate or empty identities, invalid selections, unknown
platforms and malformed release policy. Moon discovers package tests directly;
there is no second inventory of individual package-test names.

`index check` validates the current case registry and candidate manifest.
The driver checks actual assertion routes before platform filtering; it does
not generate or consume a parallel assertion-quality catalog.
Duplicate-stimulus checks preserve argument order, input bytes, fixtures,
environment and timing. Consolidation must preserve original assertions,
aliases and oracle routes.

Direct assertions and original corpus expectations establish the finite scope.
Index membership, labels and differential equality alone do not establish
local contract coverage or upstream parity.
