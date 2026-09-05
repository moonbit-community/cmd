# tr for moonx

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

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
SET2-filling `[CHAR*]` repetition. Operates on raw bytes under the fixed
`LC_ALL=C` profile; locale data beyond that profile is intentionally not
consulted.
