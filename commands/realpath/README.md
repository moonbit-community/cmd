# realpath

Version **0.1.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Print canonical paths for one or more operands:

```sh
moonx cli/realpath -e input.txt
moonx cli/realpath -z input.txt other.txt
```

`-e`/`--canonicalize-existing` requires every component to exist, and
`-z`/`--zero` terminates records with NUL bytes. Operands are handled
independently; a failed operand does not erase earlier output. Missing-path `-m`
semantics and other metadata-dependent modes are not included.
