# Foundation and command migration report

- Historical period: 2026-08-26—2026-08-30
- Scope: repository identity, command package migration, and policy boundary
- Status: archived foundation

## What changed

The repository was established as a collection of publishable MoonBit command
modules rather than one monolithic executable. The initial migration defined
the project scope, command inventory, package metadata, and the Native/Wasm
target contract. Read-only commands, filesystem mutation commands, and
process-oriented commands were migrated in separate batches so that policy
authority could be made explicit before publishing the restricted commands.

The package split was completed before compatibility expansion. Legacy command
trees were removed instead of kept as a compatibility shim. The resulting
catalog is the 48-command local inventory described by the current support
record; MoonX exposes the subset that has a publishable asset.

## Historical delivery points

| Commit | Delivery |
| --- | --- |
| `4307653` | Project scope and repository identity |
| `a467e08` | Initial command migration plan |
| `9990e8b` | First module release metadata |
| `34a9b87` | First read-only command batch |
| `39f8ec9` | Filesystem mutation command batch |
| `7175887` | Restricted process and language command batch |
| `9593758` | Policy-controlled command scope |
| `31f05d4` | Compatibility and policy hardening |
| `282c5ea` | Commands split into publishable modules |
| `978e3c9` | Legacy command tree removed |

## Decisions carried forward

- Wasm policy is supplied by the harness/runtime, not reimplemented by each
  command. Commands request operations and fail when the harness denies them.
- A command is not considered portable merely because it parses an option;
  unsupported capabilities must fail before mutation.
- `timeout` remains local-only because the published Wasm surface does not
  provide portable process-group cancellation.
- Host command delegation is not an implementation strategy for `sh`, `make`,
  or the network commands.

These decisions are now consolidated in
[`ADR-0002`](../adr/0002-policy.md), [`ADR-0006`](../adr/0006-process.md),
[`ADR-0007`](../adr/0007-language.md), and
[`ADR-0009`](../adr/0009-safety.md).

## Historical boundary

This report records the migration sequence, not a claim that the early batches
were already GNU-compatible. The strict support claims begin with the unified
runner and pinned upstream baselines documented in the next report.

