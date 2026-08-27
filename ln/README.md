# ln

Create symbolic links with `-s`, including force replacement (`-f`), explicit
link destinations (`-T`), directory destinations, and verbose output. Hard
links require a policy-checked runtime primitive that is not exposed by the
portable filesystem API, so this package fails closed for `ln` without `-s`.
