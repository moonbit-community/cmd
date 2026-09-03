# head for moonx

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Print the first lines or bytes of files or stdin:

```sh
printf '1\n2\n3\n' | moonx cli/head -n 2
moonx cli/head -c 16 data.bin
```

Options: `-n N` first N lines (default 10), `-c N` first N bytes, `-q`/`-v`
control the `==> file <==` headers shown for multiple files.

The Wasm artifact stopped after the requested quota for the tested file.
Unbounded-pipe timing, constant-memory behavior, and large binary inputs need
separate resource probes before they are compatibility guarantees.

With no file operand, the command silently reads stdin until EOF or the quota
is satisfied; terminal, pipe, redirection, and explicit `-` paths are clean.
