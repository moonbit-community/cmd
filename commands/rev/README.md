# rev

Version **0.1.1** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Reverse each input line byte-for-byte:

```sh
printf 'abc\n' | moonx cli/rev
moonx cli/rev input.txt
```

Line-feed bytes and the absence of a final line feed are preserved. Input is
standard input or one file operand; multiple files are rejected. The profile
uses C-locale byte semantics, so non-UTF-8 input is handled without decoding
it; multibyte locale character semantics are not claimed.

The unreleased workspace adds standalone `--version`, which prints the command
name and package version and exits successfully without reading input.
Use `--help` to display usage.
