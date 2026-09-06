# cmd tests

The `runner/` package is the single black-box validation entry point for the
`cmd` workspace. It provides native compatibility, Wasm policy, and pinned
upstream differential suites. All suites consume artifacts built by the
caller; they do not build command packages implicitly.

This module is for repository validation and is not part of the published
command modules.

The published-consumer check is `moon run --target native tests/release_runner`.
It is also pure MoonBit and consumes the exact package versions in its release
manifest; it does not rebuild command packages.
