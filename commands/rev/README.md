# rev

The `cli/rev@0.1.0` candidate reverses the bytes on each input line. It reads standard
input, or one file operand, and preserves each line-feed byte and the absence
of a final line feed. The implementation deliberately uses C-locale byte
semantics, so malformed UTF-8 is handled without decoding.

Only `--help` is supported as an option in this release. Multiple input files
are rejected explicitly. The support record in `docs/compatibility.md`
separates local Native/Wasm verification from published MoonX behavior.
