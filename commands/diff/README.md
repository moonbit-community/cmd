# diff

Version **0.1.1** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Compare two regular files, using `-` for stdin. Normal output identifies
inserted, deleted and changed lines; `-u/-U` selects unified output and
`-c/-C` selects context output, with three context lines by default.

```sh
moonx cli/diff old.txt new.txt
moonx cli/diff -u --label old --label new old.txt new.txt
```

`-q/--brief` reports differences without a patch. `-s/--report-identical-files`
reports equal files. `-a/--text` treats NUL-containing inputs as text, preserving
NUL and malformed UTF-8 bytes. Repeated `--label` options set the displayed
left and right names, including brief, identical and binary reports.

Exit status is 0 for identical files, 1 for a difference, and 2 for an input
or option error. Directory recursion, whitespace transformations, and locale
collation are outside this release. Timestamp headers honor `TZ`, `TZDIR`,
64-bit TZif transitions and explicit POSIX DST rules, including dates after
2038. With no `TZ`, the host's `/etc/localtime` is used. Missing timezone
data is an error. Unified output uses ISO timestamps and context output uses the
traditional weekday/month/day format. Use `--label` for stdin or hosts without
a timezone database. `--help` and `--version` are available.
Both files are buffered. Edit-trace storage grows with the number of changes;
this first version is intended for modest text files, not large unrelated
inputs. Different equally short edit scripts can select different hunk boundaries.
