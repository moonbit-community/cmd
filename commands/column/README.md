# column

Version **0.1.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Format delimited input as an aligned table:

```sh
printf 'name\tage\nAda\t36\n' | moonx cli/column -t
printf 'a:b\ncc:ddd\n' | moonx cli/column -t -s : -o ' | '
```

`-t`/`--table` splits rows into fields and aligns each column. `-s` selects a
single-character input separator and `-o` selects the output separator. Without
`-t`, input records are copied unchanged. The implementation uses byte-oriented
field widths and does not claim terminal-width discovery, locale display widths,
or the full util-linux table grammar.

Version 0.1.0 has known compatibility gaps: default copy-through differs from
upstream columnation, and table output omits the final newline. See the
[follow-up record](../../docs/command-followups.md) before relying on exact
upstream formatting.
