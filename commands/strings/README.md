# strings

Version **0.1.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Print printable byte sequences from files or standard input:

```sh
printf 'xxhello\000world\n' | moonx cli/strings
moonx cli/strings -n 6 data.bin
```

The default minimum sequence length is four bytes. `-n`/`--bytes` changes the
minimum, `-t` selects binary/octal/hex address output, `-o` selects octal
addresses, and `-f` prefixes each record with its file name. `-a` is accepted
for the GNU all-input spelling. The supported encoding is the C-locale byte
profile; multibyte and wide-character decoding are outside this release.
`--help` and `--version` are available.

Known 0.1.0 deviations: GNU's decimal `-t d` and single-byte `-e s` are rejected,
while `-e b` incorrectly selects single-byte scanning instead of UTF-16 big
endian. TAB ends a sequence here. These are pending command fixes, not upstream
API restrictions; see the [follow-up record](../../docs/command-followups.md).
