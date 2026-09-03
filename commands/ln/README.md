# ln

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Create symbolic links with `-s`, including force replacement (`-f`), explicit
link destinations (`-T`), directory destinations, and verbose output. Hard
links require a policy-checked runtime primitive that is not exposed by the
portable filesystem API, so this package fails closed for `ln` without `-s`.
The failure occurs before link mutation. See the
[support record](../../docs/compatibility.md).
