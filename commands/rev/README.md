# rev

Version **0.1.2** behavior is documented here. The
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

## Standalone metadata

Standalone `--version` prints exactly `rev 0.1.2` followed by one
newline. Standalone `--help` starts with `Usage: rev`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
