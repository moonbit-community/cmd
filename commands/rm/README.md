# rm

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Remove files, empty directories with `-d`, or directory trees with `-r`/`-R`.
Supports force (`-f`) and verbose (`-v`) modes. Recursive deletion never follows symbolic
links and refuses final dot/dot-dot operands. Windows accepts both slash and
backslash separators for this operand check; on POSIX a backslash remains part
of the filename. Root protection is on by default and follows
`--preserve-root` / `--no-preserve-root`; an explicitly named cwd
does not receive an extra repository policy. Operand failures do
not prevent later safe operands from being processed; the final status records
any failure. File access authorization belongs to the caller or host. Accepting
`--no-preserve-root` does not establish a tested root-deletion contract; that
destructive operation is not part of the validation fixtures. Interactive
`-i`/`-I` modes are not implemented.
