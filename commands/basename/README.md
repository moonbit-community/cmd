# basename

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Remove directory components from path operands. Supports `-a`/`--multiple`,
`-s`/`--suffix`, and NUL-delimited output with `-z`.

An empty operand produces an empty record; repeated separators and root paths
follow the coreutils byte-oriented path rules.
