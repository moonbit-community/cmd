# rev

Version **0.1.3** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Reverse each input line byte-for-byte:

```sh
printf 'abc\n' | moonx cli/rev
moonx cli/rev input.txt
```

Line-feed bytes and the absence of a final line feed are preserved. Input is
standard input when operands are absent; multiple file operands are processed
in order without inserted bytes, and later files continue after an error.
An explicit `-` is a filename in the frozen util-linux 2.40 profile; this
replaces the previous workspace stdin extension while published behavior
remains frozen. The reader retains only the current record. The profile
uses C-locale byte semantics, so non-UTF-8 input is handled without decoding
it; multibyte locale character semantics are not claimed.

## Standalone metadata

Standalone `--version` prints exactly `rev 0.1.3` followed by one
newline. Standalone `--help` starts with `Usage: rev`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
