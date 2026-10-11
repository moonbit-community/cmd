# column

Version **0.1.0** is a local candidate. See the
[support record](../../docs/compatibility.md) for verification and release status.

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
