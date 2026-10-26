# Deferred rg compression snapshot

Frozen: 2026-10-26, before compressed search was removed from the rg migration
candidate at the user's request. This directory is an unpublished development
backup, excluded from the main workspace and from `cli/rg` packaging.

It preserves the pure MoonBit gzip adapter, imported bzip2/Brotli/LZ4/Zstandard
components, new Unix compress and legacy LZMA decoders, XZ/LZMA2 container work,
the incremental decoder interface, original component tests, frozen fixtures,
and the former CLI integration source. `SHA256SUMS` records the copied decoder
files. `integration/` records the CLI integration and local contract results.

Observed before deferral: 275 imported codec/checksum tests passed on Native and
Wasm; four adapter regression tests passed on Wasm, including the eight frozen
fixtures with tiny buffers, framed concatenation, truncation and gzip partial
output; twenty local Wasm CLI contracts passed, including eight compressed
fixtures and two preprocessor probes. These bounded checks do not establish
complete compression compatibility. XZ filters, LZ4 legacy frames, broader
corruption/concatenation semantics, memory retention and immutable Linux oracle
acceptance remain unfinished. No performance acceptance exists.

The local `moon.work` isolates this backup. To recheck its adapter tests, run
`MOON_HOME="$HOME/.moon-accounts/cli" moon test --target wasm --release --deny-warn internal/codec/stream`
from this directory. Do not publish this module or include it in the main
workspace. Restore compressed search only through a separate reviewed change.
