# head for moonx

Observed native/Wasm profile (2026-09-04): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable unified-runner results and exclusions.

Print the first lines or bytes of files or stdin:

```sh
printf '1\n2\n3\n' | moonx cli/head -n 2
moonx cli/head -c 16 data.bin
```

Options: `-n N` first N records (default 10), `-c N` first N bytes, and
`-q`/`-v` header control. `-z` makes line records NUL-terminated. Count values
accept attached, separate, and long-option forms, the legacy `-NUM` spelling,
negative counts to exclude the last NUM units, an explicit `+NUM`, and
documented decimal, short binary, and IEC (`KiB` through `QiB`) size suffixes.
The obsolete first-argument form supports its documented `b`/`k`/`m` units and
`c`/`l`/`q`/`v` modifiers. The last `-n`/`-c` and `-q`/`-v` occurrence controls
its mode.

Positive prefixes stop after the requested quota. Negative record counts keep
only the excluded suffix in memory; negative byte counts keep at most the
requested suffix plus one input chunk.

With no file operand, the command silently reads stdin until EOF or the quota
is satisfied; terminal, pipe, redirection, and explicit `-` paths are clean.
