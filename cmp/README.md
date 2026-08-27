# cmp

Compare two inputs byte by byte. Supports silent mode (`-s`), listing every
difference (`-l`), a byte limit (`-n`), and independent initial skips (`-i`).
Exit statuses are 0 for equal, 1 for different, and 2 for an error.
