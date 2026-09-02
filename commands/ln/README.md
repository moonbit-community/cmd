# ln

Create symbolic links with `-s`, including force replacement (`-f`), explicit
link destinations (`-T`), directory destinations, and verbose output. Hard
links require a policy-checked runtime primitive that is not exposed by the
portable filesystem API, so this package fails closed for `ln` without `-s`.
The failure occurs before link mutation. See the
[Phase 4 filesystem spike](../../docs/spikes/2026-09-03-filesystem-primitives.md).
