# tr for moonx

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Translate, squeeze, or delete bytes read from stdin:

```sh
printf 'hello' | moonx cli/tr 'a-z' 'A-Z'
printf 'a  b' | moonx cli/tr -s ' '
moonx cli/tr -d '\n' < file.txt
```

Options: `-d` delete SET1 bytes, `-s` squeeze repeats, `-c` complement
SET1. Sets support escapes (`\n`, `\t`, ...), byte ranges (`a-z`), and the
classes `[:lower:]`, `[:upper:]`, `[:digit:]`, `[:alpha:]`, `[:alnum:]`,
`[:space:]`, `[:xdigit:]`. Operates on bytes; set characters must be
Latin-1.
