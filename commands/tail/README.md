# tail for moonx

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Print the last lines or bytes of files or stdin:

```sh
printf '1\n2\n3\n4\n' | moonx cli/tail -n 2
printf '1\n2\n3\n4\n' | moonx cli/tail -n +3   # from line 3 to the end
moonx cli/tail -n 100 huge.log
```

Options: `-n N` last N lines (default 10), `-n +K` from line K, `-c N` last
N bytes, `-c +K` from byte K, `-q`/`-v` header control, `-f`/`--follow` to
follow an open file descriptor, and `-s SEC`/`--sleep-interval SEC` to set the
polling interval (default 1 second).

The observed file paths produced the requested line/byte suffixes and `+K`
forms. Follow mode emits the initial selection, then emits bytes appended to
each regular file. A file truncated in place is followed from byte zero. The
descriptor remains open across renames, matching `tail -f`; deleting and
recreating a path is not followed, because `-F` is not implemented.

With no file operand, `-f` silently reads stdin through EOF and exits, matching
the upstream finite-pipe behavior. Regular-file follow is polling-based and
works on the native and Wasm targets; it does not require host file-notify
APIs.
