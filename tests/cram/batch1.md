# Batch 1 Read-only Commands

These tests cover normal output, option combinations, boundary inputs, and
failure statuses for the first post-migration command batch.

## echo

```mooncram
$ echo.exe hello moonbit
hello moonbit
```

```mooncram
$ echo.exe -n value && echo '|'
value|
```

```mooncram
$ echo.exe -e 'one\ntwo'
one
two
```

```mooncram
$ echo.exe -E 'one\ntwo'
one\ntwo
```

```mooncram
$ echo.exe -e 'before\cafter' && echo '|'
before|
```

## pwd

```mooncram
$ test "$(pwd.exe -L)" = "$PWD" && echo logical-directory-ok
logical-directory-ok
```

```mooncram
$ pwd.exe extra >/dev/null 2>&1
[2]
```

## basename and dirname

```mooncram
$ basename.exe /usr/bin/sort
sort
```

```mooncram
$ basename.exe archive.tar .tar
archive
```

```mooncram
$ basename.exe -a -s .txt /tmp/a.txt b.txt plain
a
b
plain
```

```mooncram
$ basename.exe ////
/
```

```mooncram
$ basename.exe -az /a/b /c/d | xxd.exe -p
62006400
```

```mooncram
$ dirname.exe /usr/bin/ / tmp/file
/usr
/
tmp
```

```mooncram
$ dirname.exe filename
.
```

```mooncram
$ dirname.exe -z /a/b c | xxd.exe -p
2f61002e00
```

## printenv

```mooncram
$ BATCH1_PRINTENV=visible printenv.exe BATCH1_PRINTENV
visible
```

```mooncram
$ printenv.exe BATCH1_VARIABLE_THAT_DOES_NOT_EXIST
[1]
```

```mooncram
$ BATCH1_PRINTENV=ok printenv.exe -0 BATCH1_PRINTENV | xxd.exe -p
6f6b00
```

## seq

```mooncram
$ seq.exe 3
1
2
3
```

```mooncram
$ seq.exe 5 -2 1
5
3
1
```

```mooncram
$ seq.exe -s, 2 4 && echo marker
2,3,4
marker
```

```mooncram
$ seq.exe -w 8 10
08
09
10
```

```mooncram
$ seq.exe 1 0 2 >/dev/null 2>&1
[1]
```

## test

```mooncram
$ test.exe nonempty && echo true
true
```

```mooncram
$ test.exe 10 -gt 2 && echo integer-true
integer-true
```

```mooncram
$ printf data > present.txt && test.exe -f present.txt -a -r present.txt && echo file-true
file-true
```

```mooncram
$ test.exe ! -e absent.txt && echo missing-true
missing-true
```

```mooncram
$ test.exe ''
[1]
```

```mooncram
$ test.exe 1 -eq nope >/dev/null 2>&1
[2]
```

## cmp

```mooncram
$ printf abc > same-a && printf abc > same-b && cmp.exe same-a same-b && echo equal
equal
```

```mooncram
$ printf abc > left && printf axc > right && cmp.exe left right
left right differ: byte 2, line 1
[1]
```

```mooncram
$ cmp.exe -s left right
[1]
```

```mooncram
$ cmp.exe -n 1 left right && echo prefix-equal
prefix-equal
```

```mooncram
$ cmp.exe -l left right
     2 142 170
[1]
```

```mooncram
$ printf xabc > skipped-a && printf yabc > skipped-b && cmp.exe -i 1 skipped-a skipped-b && echo skip-equal
skip-equal
```

```mooncram
$ dd if=/dev/zero of=large-a bs=65536 count=2 2>/dev/null && cp large-a large-b && dd if=large-a bs=17 2>/dev/null | cmp.exe - large-b && echo streamed-equal
streamed-equal
```

## sha256sum

```mooncram
$ printf abc | sha256sum.exe
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  -
```

```mooncram
$ printf abc > data.bin && sha256sum.exe data.bin
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  data.bin
```

```mooncram
$ sha256sum.exe data.bin > checksums && sha256sum.exe -c checksums
data.bin: OK
```

```mooncram
$ printf changed > data.bin && sha256sum.exe -c checksums
data.bin: FAILED
[1]
```

```mooncram
$ dd if=/dev/zero bs=1048576 count=1 2>/dev/null | sha256sum.exe
30e14955ebf1352266dc2ff8067e68104607e750abb9d3b36582b8af909fcb58  -
```

## grep

```mooncram
$ printf 'alpha\nbeta\nalphabet\n' | grep.exe '^alpha$'
alpha
```

```mooncram
$ printf 'Alpha\nbeta\n' | grep.exe -in alpha
1:Alpha
```

```mooncram
$ printf 'cat\nconcatenate\none cat\n' | grep.exe -Fw cat
cat
one cat
```

```mooncram
$ printf 'a\nb\nc\n' | grep.exe -vc b
2
```

```mooncram
$ printf 'hit\n' > one.txt && printf 'miss\nhit\n' > two.txt && grep.exe -n hit one.txt two.txt
one.txt:1:hit
two.txt:2:hit
```

```mooncram
$ mkdir -p grep-tree/sub && printf 'needle\n' > grep-tree/a && printf 'needle\n' > grep-tree/sub/b && grep.exe -rl needle grep-tree
grep-tree/a
grep-tree/sub/b
```

```mooncram
$ printf text | grep.exe '[' >/dev/null 2>&1
[2]
```

```mooncram
$ printf text | grep.exe absent
[1]
```

```mooncram
$ awk 'BEGIN { for (i = 0; i < 10000; i++) print "ordinary"; print "needle" }' | grep.exe -c needle
1
```

## ls

```mooncram
$ mkdir -p listing/sub && printf a > listing/a && printf b > listing/b && printf h > listing/.hidden && ls.exe listing
a
b
sub
```

```mooncram
$ ls.exe -AF listing
.hidden
a
b
sub/
```

```mooncram
$ ls.exe -dF listing
listing/
```

```mooncram
$ ls.exe missing >/dev/null 2>&1
[1]
```

```mooncram
$ ls.exe -l >/dev/null 2>&1
[2]
```

## find

```mooncram
$ mkdir -p tree/sub && printf a > tree/a.txt && printf b > tree/b.md && printf c > tree/sub/c.txt && (cd tree && find.exe . -name '*.txt' -type f | sort)
./a.txt
./sub/c.txt
```

```mooncram
$ (cd tree && find.exe . -maxdepth 1 -type f | sort)
./a.txt
./b.md
```

```mooncram
$ (cd tree && find.exe . \( -name '*.md' -o -name 'c.txt' \) | sort)
./b.md
./sub/c.txt
```

```mooncram
$ (cd tree && find.exe . -mindepth 1 -maxdepth 1 -print0 | xxd.exe -p)
2e2f612e747874002e2f622e6d64002e2f73756200
```

```mooncram
$ find.exe tree -exec echo.exe '{}' ';' >/dev/null 2>&1
[1]
```

## Additional option and failure coverage

Escape bytes and option termination remain binary-safe.

```mooncram
$ echo.exe -e '\0101\x42' | xxd.exe -p
41420a
```

```mooncram
$ basename.exe -- -option && basename.exe word word
-option
word
```

```mooncram
$ dirname.exe -- -option /a//b//
.
/a
```

Logical and physical working-directory modes agree with the corresponding
shell view, including a symbolic-link entry point.

```mooncram
$ mkdir -p physical-dir && ln -s physical-dir physical-link && (cd physical-link && test "$(pwd.exe -P)" = "$(pwd -P)") && echo physical-ok
physical-ok
```

Missing environment names preserve earlier selected output and return the
documented failure status.

```mooncram
$ BATCH1_FIRST=one printenv.exe BATCH1_FIRST BATCH1_MISSING
one
[1]
```

```mooncram
$ seq.exe 0.5 0.5 1.5
0.5
1
1.5
```

```mooncram
$ seq.exe 3 1 | wc.exe -l
0
```

Expression precedence, string comparison, directory predicates, and syntax
errors are checked independently.

```mooncram
$ test.exe -z '' -a \( value = value -o '' \) && echo precedence-ok
precedence-ok
```

```mooncram
$ test.exe a '<' b -a a != b && echo strings-ok
strings-ok
```

```mooncram
$ mkdir -p test-directory && test.exe -d test-directory && echo directory-ok
directory-ok
```

```mooncram
$ test.exe \( value = value >/dev/null 2>&1
[2]
```

EOF differences, asymmetric skips, and I/O failures exercise all `cmp` exit
classes.

```mooncram
$ printf ab > short-input && printf abc > long-input && cmp.exe short-input long-input 2>&1
cmp: EOF on short-input after byte 2, line 1
[1]
```

```mooncram
$ printf xabc > skip-left && printf yyabc > skip-right && cmp.exe -i 1:2 skip-left skip-right && echo asymmetric-skip-ok
asymmetric-skip-ok
```

```mooncram
$ cmp.exe does-not-exist long-input >/dev/null 2>&1
[2]
```

Multiple digest inputs, NUL termination, malformed manifests, and missing
inputs are covered separately from checksum mismatches.

```mooncram
$ printf a > sha-a && printf b > sha-b && sha256sum.exe sha-a sha-b
ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb  sha-a
3e23e8160039594a33894f6564e1b1348bbd7a0088d42c4acb73eeaed59c009d  sha-b
```

```mooncram
$ sha256sum.exe -z sha-a | xxd.exe -p
636139373831313263613162626463616661633233316233396132336463
346461373836656666383134376334653732623938303737383561666565
3438626220207368612d6100
```

```mooncram
$ printf 'malformed\n' > malformed-checks && sha256sum.exe -c malformed-checks >/dev/null 2>&1
[1]
```

```mooncram
$ sha256sum.exe missing-digest-input >/dev/null 2>&1
[1]
```

Pattern files, exact lines, file-selection modes, and filename-prefix controls
cover the remaining documented `grep` branches.

```mooncram
$ printf 'alpha\n' > grep-patterns && printf 'alpha\nalphabet\nbeta\n' > grep-input && grep.exe -f grep-patterns -x grep-input
alpha
```

```mooncram
$ printf 'hit\n' > has-hit && printf 'miss\n' > lacks-hit && grep.exe -l hit has-hit lacks-hit && grep.exe -L hit has-hit lacks-hit
has-hit
lacks-hit
```

```mooncram
$ grep.exe -q hit has-hit && echo quiet-ok
quiet-ok
```

```mooncram
$ grep.exe -H hit has-hit && grep.exe -h hit has-hit has-hit
has-hit:hit
hit
hit
```

```mooncram
$ printf 'alpha\nbeta\ngamma\n' | grep.exe -e alpha -e gamma
alpha
gamma
```

Hidden-entry modes, symbolic-link indicators, recursive headers, and multiple
operand formatting extend the deterministic `ls` contract.

```mooncram
$ ls.exe -A listing
.hidden
a
b
sub
```

```mooncram
$ ln -s a listing/link && ls.exe -dF listing/link
listing/link@
```

```mooncram
$ ls.exe -R listing
listing:
a
b
link
sub

listing/sub:
```

Path predicates, negation, symbolic-link handling, and invalid expressions
complete the read-only `find` coverage.

```mooncram
$ (cd tree && find.exe . -type f ! -name '*.txt')
./b.md
```

```mooncram
$ (cd tree && find.exe . -path './sub/*')
./sub/c.txt
```

```mooncram
$ ln -s sub tree/link && find.exe tree/link -type l
tree/link
```

```mooncram
$ find.exe tree -unknown >/dev/null 2>&1
[1]
```
