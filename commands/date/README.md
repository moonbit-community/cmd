# date

Version **0.1.1**. See the [support record](../../docs/compatibility.md) for release evidence.

Print or format a timestamp:

```sh
moonx cli/date -u -d '@0' '+%Y-%m-%dT%H:%M:%SZ'
TZ=Asia/Shanghai moonx cli/date -d '@0' '+%H:%M %z %Z'
moonx cli/date -u -d '@-0.5' --iso-8601=ns
```

`-u`/`--utc` selects UTC. Otherwise `TZ` selects a named TZif zone, an
absolute TZif path, or a POSIX timezone with explicit DST rules. With
no TZ, `/etc/localtime` is used. `TZDIR` changes the named-zone directory.
Missing/invalid timezone data fails explicitly; on Windows use `-u`, a
POSIX TZ value or a TZif file when no timezone database is installed.

`-d`/`--date` accepts `YYYY-MM-DD` (local midnight), local
`YYYY-MM-DDTHH:MM:SS[.fraction]` (a space may replace `T`), or `@SECONDS`,
including signed fractions of up to nine digits. Input timezone suffixes
are not supported; select the zone with `TZ` or `-u`.
DST gaps and ambiguous local times are
rejected; use an epoch timestamp to choose an exact instant.
`-I`/`--iso-8601` accepts `date`, `hours`, `minutes`, `seconds` or `ns`.
`-R`/`--rfc-email` emits an RFC email timestamp. These output selectors
cannot be combined with each other or a `+FORMAT` operand.

Supported format fields are `%Y %y %m %d %e %H %M %S %j %a %A %b %h %B
%F %T %R %s %N %z %Z %%`. Names use the C locale. Other known GNU fields
and format modifiers are rejected. The current clock has millisecond
precision; supplied fractional epochs retain nanoseconds. Relative-date
parsing, leap-second TZif files and setting the system clock are not
implemented. The released date/time API accepts offsets within ±18 hours;
larger offsets fail explicitly. `--help` and `--version` are available.
