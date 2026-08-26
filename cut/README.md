# cut for moonx

Select fields or character positions from each line:

```sh
printf 'x,y,z\n' | moonx mooxCLI/cmd/cut -d, -f1,3
moonx mooxCLI/cmd/cut -c 1-4 fixed.txt
```

Options: `-f LIST` field list, `-c LIST` character list, `-d CHAR` field
delimiter (default TAB), `-s` skip lines without the delimiter. Lists
accept `N`, `N-M`, `N-`, and `-M`, separated by commas; output preserves
input order.
