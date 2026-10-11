# strings

Version **0.1.0** is a local candidate. See the
[support record](../../docs/compatibility.md) for verification and release status.

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
