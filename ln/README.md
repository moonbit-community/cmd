# ln

Create symbolic links with `-s`, including force replacement (`-f`), explicit
link destinations (`-T`), directory destinations, and verbose output. Hard
Hard links require a policy-checked runtime link primitive that is not exposed
by the current Moonrun filesystem API, so this package fails closed for `ln`
without `-s` rather than bypassing the sandbox.
