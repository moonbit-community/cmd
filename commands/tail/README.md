# tail for moonx

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Print the last lines or bytes of files or stdin:

```sh
printf '1\n2\n3\n4\n' | moonx cli/tail -n 2
printf '1\n2\n3\n4\n' | moonx cli/tail -n +3   # from line 3 to the end
moonx cli/tail -n 100 huge.log
```

Options: `-n N` last N lines (default 10), `-n +K` from line K, `-c N` last
N bytes, `-c +K` from byte K, `-q`/`-v` header control.

The observed file paths produced the requested line/byte suffixes and `+K`
forms. Large-file memory use and endless-pipe behavior were not measured.
There is no verified `-f` (follow) mode.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.
