# paste for moonx

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Merge corresponding lines of files:

```sh
moonx cli/paste -d, nums.txt letters.txt
moonx cli/paste -s -d, nums.txt   # serial: one output line per file
```

Options: `-d LIST` delimiter characters cycled between columns (default
TAB; `\t`, `\n`, `\0` for empty, and `\\` are understood), `-s` serial
mode. Each `-` argument reads the full stdin content.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.
