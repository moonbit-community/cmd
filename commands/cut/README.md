# cut for moonx

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Select fields or character positions from each line:

```sh
printf 'x,y,z\n' | moonx cli/cut -d, -f1,3
moonx cli/cut -c 1-4 fixed.txt
```

Options: `-f LIST` field list, `-b LIST` byte list, `-c LIST` character list
(the latter two are identical under the fixed C-locale byte profile), `-d CHAR` field
delimiter (default TAB), `-s` skip lines without the delimiter, and `-z`
for NUL-delimited records. Lists
accept `N`, `N-M`, `N-`, and `-M`, separated by commas; output preserves
input order.

An empty `-d` value is rejected because the delimiter must be one byte.
Delimiter and `-s` options are rejected outside field mode.
