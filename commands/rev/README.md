# rev

Version **0.1.0** behavior is documented here. The
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
