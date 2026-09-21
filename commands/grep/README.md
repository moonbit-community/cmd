# grep

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Search text using basic regular expressions by default, extended expressions
with `-E`, or fixed strings with `-F`; `-G` restores basic syntax. Options include
`-E`, `-F`, `-G`, `-o`, `-i`, `-v`, `-n`, `-b`, `-c`, `-l`, `-L`, `-q`,
`-H`, `-h`, `-x`, `-w`, `-e`, `-f`, and recursive `-r`. `-A/-B/-C` emit
context with GNU-style selected/context separators, while `-z` switches input
and output records to NUL. Recursive reads accept repeated `--include` and
`--exclude` basename patterns using portable `*` and `?` wildcards.

Binary input defaults to GNU 3.12's `grep: NAME: binary file matches` stderr
notice;
`--binary-files=text` (or `-a`) searches and emits raw records, and
`--binary-files=without-match` skips binary inputs. `-s` suppresses file-read
diagnostics without hiding status 2. Matching, offsets, and record boundaries
use a byte-oriented C-locale profile without changing the process environment.
`-o` emits nonempty, nonoverlapping matches using leftmost-longest selection;
`-b -o` reports the offset of each match. No group separator is emitted without
context options. Backreferences are explicitly rejected because the public
regex engine cannot represent their semantics. Locale-sensitive collation and
multibyte case folding are not currently implemented. Exit statuses are 0 for a selected
line/file, 1 for no selection, and 2 for an error.
