# dirname

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Remove the final path component. Multiple operands and NUL-delimited output
with `-z` are supported. Empty operands produce `.`, root remains `/`, and
repeated separators are handled without filesystem access.
