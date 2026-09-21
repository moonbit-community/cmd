# tr for moonx

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Translate, squeeze, or delete bytes read from stdin:

```sh
printf 'hello' | moonx cli/tr 'a-z' 'A-Z'
printf 'a  b' | moonx cli/tr -s ' '
moonx cli/tr -d '\n' < file.txt
```

Options: `-d` delete SET1 bytes, `-s` squeeze repeats, and `-c`/`-C`
complement SET1. `-t` truncates SET1 to SET2's length. Sets support escapes
(`\n`, `\t`, `\123`), byte
ranges, C-locale character and equivalence classes, and `[CHAR*COUNT]` or
SET2-filling `[CHAR*]` repetition. Operates on raw bytes with C-locale rules;
locale data beyond that profile is not implemented. The command does not
rewrite environment locale variables.
