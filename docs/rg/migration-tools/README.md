# One-time migration records

These `.mbtx.source` files preserve the actual pure MoonBit import/adaptation
steps. They are historical source records, not commands to rerun on the migrated
tree. In particular, the initial import predates compression deferral and would
reintroduce files that are intentionally outside the current workspace.

Current registration and observation tools live under `tools/rg_*.mbtx`.
Frozen generated Unicode/encoding/regex/flag data are retained from the pinned
source. No upstream Python/Shell/Rust generator is imported as project automation.
Any future data regeneration requires a separately reviewed pure MoonBit tool,
pinned input checksums and semantic comparisons against those fixed sources.
