# date

Version **0.1.0** is a local candidate. See the
[support record](../../docs/compatibility.md) for verification and release status.

Print or format a timestamp:

```sh
moonx cli/date -u -d '@0' '+%Y-%m-%dT%H:%M:%SZ'
moonx cli/date -u -d '1970-01-02 03:04:05' '+%s'
```

The implementation provides a deterministic UTC profile. `-u`/`--utc`,
`-d`/`--date` with ISO-like input or `@SECONDS`, `-I`/`--iso-8601`, and
`-R`/`--rfc-email` are supported. Format directives include the common GNU
date fields (`%Y %m %d %e %H %M %S %j %a %A %b %B %F %T %s %z %Z %%`). Local
timezone database lookup, timezone mutation, relative-date parsing and setting
the system clock are outside this release.
