# hexdump

Version **0.1.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Display binary data as numbers and readable characters:

```sh
moonx cli/hexdump -C data.bin
moonx cli/hexdump -s16 -n32 -v data.bin
printf 'abc' | moonx cli/hexdump -b
```

`-C` prints hexadecimal bytes and an ASCII column. `-b`, `-c`, and `-X`
select one-byte octal, escaped characters, and hexadecimal. `-d`, `-o`, and
`-x` print two-byte decimal, octal, and hexadecimal values. Without a format
option, two-byte hexadecimal values use the compact default layout. Repeated
format options produce one line per selected format, in option order.

Files are concatenated before formatting; no file, or `-`, reads stdin.
`-s` skips input bytes, `-n` limits displayed bytes, and `-v` prints repeated
blocks instead of `*`. Counts accept decimal, leading-zero octal, hexadecimal,
and common `K/M/G`, `KiB/MiB/GiB`, `KB/MB/GB`, or `b` suffixes. Final partial
words are zero-padded and absent fields retain their column spacing.

`-e FORMAT` adds a custom format and `-f FILE` reads one format per nonempty,
noncomment line. Formats contain optional iteration and byte counts followed
by a quoted body, for example `4/1 "%02x " "\\n"`. Built-in and custom formats
retain their option order and share the largest input block. A final consuming
unit without an explicit iteration count repeats to fill that block. The last
whitespace byte of a repeated unit is omitted on its final iteration.

Custom conversions support integer `d/i/o/u/x/X` with 1, 2, 4, or 8 bytes,
floating `e/E/f/g/G` with 4 or 8 bytes, raw `%c`, NUL-terminated `%s` with a
precision or byte count, and `_c`, `_p`, `_u` character styles. Width,
precision, sign, alternate form, alignment, and zero padding follow the
selected C profile. `%_a[dox]` prints the current offset; only the last
`%_A[dox]` unit prints the final offset. Raw characters and strings preserve
input bytes. Numeric elements use the little-endian Native/Wasm profile;
partial elements are zero-padded and absent elements retain field spacing.
The fixed util-linux 2.40 provider rejects `%%`, unsupported conversions,
and invalid byte counts; this command keeps those rejection contracts.

`-Lalways` or `--color=always` enables `_L[color[:value][@start[-end]],...]`
after a conversion. Rules support named colors, hexadecimal or octal values,
byte strings, inverted conditions, absolute offsets, and first-match order.
Unknown color names disable that list. `-Lnever` disables color. Bare `-L`
and `auto` remain uncolored: the released public stdio API has no terminal
detection operation, so interactive automatic color is outside this profile.
Built-in formats have no color directives. Provider memory-overwrite or
nonterminating color ranges are outside the compatibility profile.

Input uses a fixed read buffer and one format block. Positive stdin skips use
read/discard. This is an intentional workspace extension: the fixed util-linux
2.40 provider rejects a positive skip on a pipe with `Illegal seek`; equivalent
named-file bytes establish the expected display. `-n0` and formats that consume
no input complete without reading stdin. `-h`/`--help` and `-V`/`--version`
are available. Errors return status 1.

## Standalone metadata

Standalone `--version` prints exactly `hexdump 0.1.2` followed by one
newline. Standalone `--help` starts with `Usage: hexdump`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
