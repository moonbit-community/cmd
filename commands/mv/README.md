# mv

Move files and directories with the policy-checked atomic rename operation.
Supports force/no-clobber selection (`-f`/`-n`), explicit target paths (`-T`),
directory destinations, and verbose output. Cross-filesystem copy-and-delete
fallback is intentionally excluded because the portable runtime does not expose a
`EXDEV` discriminator.
