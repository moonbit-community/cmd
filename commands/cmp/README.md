# cmp

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Compare two inputs byte by byte. Supports silent mode (`-s`), listing every
difference (`-l`), a byte limit (`-n`), and independent initial skips (`-i`).
When FILE2 is omitted it defaults to stdin; `-l` and `-s` are rejected when
combined.
Exit statuses are 0 for equal, 1 for different, and 2 for an error.
Comparison and status selection remain byte-oriented under `LC_ALL=C`, and an
error takes precedence over a difference that could not be fully examined.
