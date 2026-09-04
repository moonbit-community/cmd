# grep

Observed native/Wasm profile (2026-09-04): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable unified-runner results and exclusions.

Search text using MoonBit regular expressions or fixed strings. The observed
surface includes `-E`, `-F`, `-i`, `-v`, `-n`, `-b`, `-c`, `-l`, `-L`, `-q`,
`-H`, `-h`, `-x`, `-w`, `-e`, `-f`, and recursive `-r`. `-A/-B/-C` emit
context with GNU-style selected/context separators, while `-z` switches input
and output records to NUL. Recursive reads accept repeated `--include` and
`--exclude` basename patterns using portable `*` and `?` wildcards.

Binary input defaults to the `Binary file NAME matches` result;
`--binary-files=text` (or `-a`) searches and emits raw records, and
`--binary-files=without-match` skips binary inputs. `-s` suppresses file-read
diagnostics without hiding status 2. Matching, offsets, and record boundaries
use the fixed `LC_ALL=C` byte profile. Exit statuses are 0 for a selected
line/file, 1 for no selection, and 2 for an error.
