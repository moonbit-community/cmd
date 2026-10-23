# Comprehensive-plan startup inventory

This is the frozen startup source review for the user-authorized
[comprehensive plan](../../comprehensive-optimization-plan.md). It records
requirements and observed source, not passing acceptance or issue completion.

`startup-inventory.json` covers all 79 commands and 12 shared core packages at
`82ba94b01f5a4cf4e91789d73158caa87cc8a261`, whose command/core trees match
accepted actual main `4180e527`. Its SHA-256 is
`3fc872867db6fec37f60d15d300010ad0d7f436acbfa2478ec7e54bb91d27ac0`.
The component inventories and option notes are preserved byte-for-byte beside
it. Recorded source roots and line references identify that inspected revision;
later implementation must add new evidence rather than rewrite this snapshot.

`original-issue-snapshot.json` retains issues #27, #28, #30, #33 and #32 as
observed at `2026-10-23T01:42:00Z`. `original-acceptance-map.json` maps all
22 original acceptance bullets to stable pending IDs and their required stages
and evidence. All 22 remain pending. These are original-condition IDs, not
invented passing registry case IDs. The snapshot hash is
`2d15eca4074a70fc199b1158933e587949be43c688943c8d9f234c511d40e2c8`.

The old issue preamble is historical context. In particular, no stored-block
encoder claim was inferred for published gzip: an actual `cli/gzip@0.1.1`
8 MiB observation produced 320444 compressed bytes and independently decoded
to the original checksum. Algorithm classification remains unproven by that
observation alone.

Early exact published MoonX observations, native GNU builds and the dedicated
arm64 Linux VM are retained under the original workspace's ignored
`_build/verification/2026-10-23-preflight/` plus their external evidence
directories. They are preparation/diagnostics. They do not establish the
105-pair performance gate, a frozen native Linux oracle profile or formal
MoonX-vs-GNU ratios. No package was published and no issue was closed by this
startup work.
