# Batch 3 High-Authority Commands

These tests cover the restricted command-execution surface, network boundary,
permission changes, and explicit unsupported operations. Commands that spawn
children are exercised only with deterministic, short-lived fixtures.

## env

```mooncram
$ env.exe -i TEST_VALUE=from-env printenv.exe TEST_VALUE
from-env
```

```mooncram
$ env.exe -i FIRST=one SECOND=two env.exe | grep.exe -E '^(FIRST|SECOND)=' | sort.exe
FIRST=one
SECOND=two
```

```mooncram
$ env.exe -i TEST_VALUE=from-env echo.exe child-ok
child-ok
```

```mooncram
$ env.exe -i VALUE=one=two printenv.exe VALUE
one=two
```

```mooncram
$ env.exe --unset=PATH printenv.exe PATH >/dev/null 2>&1
[1]
```

## xargs

```mooncram
$ printf 'one two three\n' | xargs.exe -n 2 echo.exe
one two
three
```

```mooncram
$ printf 'one\0two\0' | xargs.exe -0 -n 1 echo.exe
one
two
```

```mooncram
$ printf '' | xargs.exe -r echo.exe should-not-run && echo no-run
no-run
```

```mooncram
$ printf 'one two\n' | xargs.exe -t -n 1 echo.exe 2>&1
echo.exe one
one
echo.exe two
two
```

```mooncram
$ printf 'one\n' | xargs.exe -n nope echo.exe >/dev/null 2>&1
[1]
```

```mooncram
$ printf "%s\n" "'unterminated" | xargs.exe echo.exe >/dev/null 2>&1
[1]
```

```mooncram
$ printf "'' value\n" | xargs.exe -n 2 echo.exe
 value
```

## timeout

```mooncram
$ timeout.exe 1s echo.exe timeout-ok
timeout-ok
```

```mooncram
$ timeout.exe 0.01s sleep.exe 0.2 >/dev/null 2>&1
[124]
```

```mooncram
$ timeout.exe 1s echo.exe -- timeout-argument
-- timeout-argument
```

```mooncram
$ timeout.exe nope echo.exe >/dev/null 2>&1
[125]
```

## sh

```mooncram
$ sh.exe -c 'printf shell-ok'
shell-ok (no-eol)
```

```mooncram
$ sh.exe -c 'exit 7' >/dev/null 2>&1
[7]
```

```mooncram
$ sh.exe -c 'VALUE="one two"; export OTHER=three; test "$VALUE" = "one two" && echo "$VALUE:$OTHER"'
one two:three
```

```mooncram
$ sh.exe -c 'printf left | grep.exe left'
left
```

```mooncram
$ sh.exe -c 'echo $(uname)' >/dev/null 2>&1
[2]
```

## make

```mooncram
$ printf 'all:\n\tprintf make-ok\n' > Makefile && make.exe -s -f Makefile
make-ok (no-eol)
```

```mooncram
$ make.exe -f missing-Makefile >/dev/null 2>&1
[2]
```

```mooncram
$ printf 'VALUE = variable\n.PHONY: all prepare\nall: prepare\n\tprintf "$(VALUE)-$@-$<"\nprepare:\n\techo dep\n' > Makefile.variables && make.exe -s -f Makefile.variables
dep
variable-all-prepare (no-eol)
```

```mooncram
$ printf 'all:\n\tprintf dry-run-must-not-execute\n' > Makefile.dry && make.exe -n -f Makefile.dry
printf dry-run-must-not-execute
```

```mooncram
$ printf 'a: b\nb: a\n' > Makefile.cycle && make.exe -f Makefile.cycle >/dev/null 2>&1
[2]
```

```mooncram
$ printf 'include other.mk\n' > Makefile.include && make.exe -f Makefile.include >/dev/null 2>&1
[2]
```

## curl and wget

```mooncram
$ curl.exe -- file:///missing-curl-resource >/dev/null 2>&1
[1]
```

```mooncram
$ curl.exe -sSf file:///missing-curl-resource >/dev/null 2>&1
[1]
```

```mooncram
$ wget.exe -- file:///missing-wget-resource >/dev/null 2>&1
[1]
```

```mooncram
$ curl.exe --help
Usage: curl [-sSf] [-o FILE] URL
```

```mooncram
$ wget.exe --help
Usage: wget [-q] [-O FILE] URL
```

## chmod

```mooncram
$ printf mode > chmod-file && chmod.exe 600 chmod-file && cat.exe chmod-file && echo
mode
```

```mooncram
$ mkdir.exe -p chmod-tree/sub && chmod.exe -R 700 chmod-tree && test.exe -x chmod-tree -a -x chmod-tree/sub && echo recursive-ok
recursive-ok
```

```mooncram
$ chmod.exe -v 755 chmod-file
mode of 'chmod-file' changed to 0755
```

```mooncram
$ chmod.exe u+x chmod-file >/dev/null 2>&1
[2]
```

```mooncram
$ chmod.exe 600 chmod-file && ln.exe -s chmod-file chmod-link && chmod.exe 777 chmod-link >/dev/null 2>&1
[1]
```

```mooncram
$ test.exe -x chmod-file >/dev/null 2>&1
[1]
```
