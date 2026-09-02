# mv

Move files and directories with the policy-checked atomic rename operation.
Supports force/no-clobber selection (`-f`/`-n`), explicit target paths (`-T`),
directory destinations, and verbose output. Cross-filesystem copy-and-delete
fallback is intentionally excluded because the portable runtime does not expose a
`EXDEV` discriminator.
The source remains intact when rename fails. See the
[Phase 4 filesystem spike](../../docs/spikes/2026-09-03-filesystem-primitives.md).
