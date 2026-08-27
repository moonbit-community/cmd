# ln

Create symbolic links with `-s`, including force replacement (`-f`), explicit
link destinations (`-T`), directory destinations, and verbose output. Hard
links are intentionally unavailable because the portable Moonrun filesystem
API does not expose a policy-checked hard-link operation.
