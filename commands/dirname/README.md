# dirname

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Remove the final path component. Multiple operands and NUL-delimited output
with `-z` are supported. Empty operands produce `.`, root remains `/`, and
repeated separators are handled without filesystem access.

The unreleased workspace adds standalone `--version`, which prints the command
name and package version and exits successfully without reading input.
Use `--help` to display usage.
