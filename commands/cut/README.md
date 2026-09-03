# cut for moonx

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Select fields or character positions from each line:

```sh
printf 'x,y,z\n' | moonx cli/cut -d, -f1,3
moonx cli/cut -c 1-4 fixed.txt
```

Options: `-f LIST` field list, `-c LIST` character list, `-d CHAR` field
delimiter (default TAB), `-s` skip lines without the delimiter. Lists
accept `N`, `N-M`, `N-`, and `-M`, separated by commas; output preserves
input order.
