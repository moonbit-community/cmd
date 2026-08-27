# Batch 2 Filesystem Mutation Commands

These tests exercise successful mutations, overwrite rules, recursive
operations, streaming boundaries, symlink safety, and failure statuses.

## mkdir

```mooncram
$ mkdir.exe mkdir-one mkdir-two && test.exe -d mkdir-one -a -d mkdir-two && echo created
created
```

```mooncram
$ mkdir.exe -p mkdir-tree/a/b && mkdir.exe -p mkdir-tree/a/b && test.exe -d mkdir-tree/a/b && echo parents-ok
parents-ok
```

```mooncram
$ mkdir.exe -v mkdir-verbose
mkdir: created directory 'mkdir-verbose'
```

```mooncram
$ mkdir.exe -m 700 mkdir-mode && test.exe -d mkdir-mode -a -x mkdir-mode && echo mode-ok
mode-ok
```

```mooncram
$ mkdir.exe mkdir-one >/dev/null 2>&1
[1]
```

```mooncram
$ mkdir.exe -m 888 invalid-mode >/dev/null 2>&1
[1]
```

## touch

```mooncram
$ touch.exe touch-a touch-b && wc.exe -c touch-a touch-b
0 touch-a
0 touch-b
0 total
```

```mooncram
$ printf preserved > touch-existing && touch.exe touch-existing && cat.exe touch-existing && echo
preserved
```

```mooncram
$ touch.exe -c touch-not-created && test ! -e touch-not-created && echo no-create-ok
no-create-ok
```

```mooncram
$ touch.exe missing-parent/touch-file >/dev/null 2>&1
[1]
```

```mooncram
$ touch.exe >/dev/null 2>&1
[1]
```

## tee

```mooncram
$ printf 'tee-value\n' | tee.exe tee-one
tee-value
```

```mooncram
$ cat.exe tee-one
tee-value
```

```mooncram
$ printf binary > tee-a && printf '%s' '-data' | tee.exe -a tee-a >/dev/null && cat.exe tee-a && echo
binary-data
```

```mooncram
$ printf duplicate | tee.exe tee-two tee-three >/dev/null && cmp.exe tee-two tee-three && cat.exe tee-two && echo
duplicate
```

```mooncram
$ dd if=/dev/zero bs=65536 count=4 2>/dev/null | tee.exe tee-large > tee-large-out && cmp.exe tee-large tee-large-out && wc.exe -c tee-large
262144 tee-large
```

```mooncram
$ printf visible | tee.exe missing-tee-parent/output 2>/dev/null
visible (no-eol)
[1]
```

## cp

```mooncram
$ printf source-data > cp-source && cp.exe cp-source cp-copy && cat.exe cp-copy && echo
source-data
```

```mooncram
$ mkdir.exe cp-destination && printf one > cp-one && printf two > cp-two && cp.exe cp-one cp-two cp-destination && cat.exe cp-destination/cp-one cp-destination/cp-two && echo
onetwo
```

```mooncram
$ printf old > cp-target && printf new > cp-new && cp.exe -n cp-new cp-target && cat.exe cp-target && echo
old
```

```mooncram
$ cp.exe -f cp-new cp-target && cat.exe cp-target && echo
new
```

```mooncram
$ ln -s cp-target cp-target-link && cp.exe cp-source cp-target-link >/dev/null 2>&1
[1]
```

```mooncram
$ cat.exe cp-target && echo
new
```

```mooncram
$ mkdir.exe -p cp-tree/sub/empty && printf visible > cp-tree/root && printf hidden > cp-tree/.hidden && printf nested > cp-tree/sub/file && cp.exe -R cp-tree cp-tree-copy && find.exe cp-tree-copy -type f | sort
cp-tree-copy/.hidden
cp-tree-copy/root
cp-tree-copy/sub/file
```

```mooncram
$ test.exe -d cp-tree-copy/sub/empty && cat.exe cp-tree-copy/.hidden cp-tree-copy/sub/file && echo
hiddennested
```

```mooncram
$ cp.exe cp-tree cp-without-recursion >/dev/null 2>&1
[1]
```

```mooncram
$ cp.exe cp-source cp-source >/dev/null 2>&1
[1]
```

```mooncram
$ cp.exe -R cp-tree cp-tree/sub/inside >/dev/null 2>&1
[1]
```

```mooncram
$ ln -s cp-source cp-source-link && cp.exe cp-source-link cp-link-copy >/dev/null 2>&1
[1]
```

```mooncram
$ dd if=/dev/zero bs=1048576 count=1 2>/dev/null > cp-large && cp.exe cp-large cp-large-copy && cmp.exe cp-large cp-large-copy && sha256sum.exe cp-large-copy
30e14955ebf1352266dc2ff8067e68104607e750abb9d3b36582b8af909fcb58  cp-large-copy
```

```mooncram
$ cp.exe -v cp-source cp-verbose
'cp-source' -> 'cp-verbose'
```

```mooncram
$ cp.exe missing-cp-source cp-nowhere >/dev/null 2>&1
[1]
```

```mooncram
$ cp.exe -T cp-one cp-two cp-destination >/dev/null 2>&1
[1]
```

## mv

```mooncram
$ printf move-me > mv-source && mv.exe mv-source mv-target && test ! -e mv-source && cat.exe mv-target && echo
move-me
```

```mooncram
$ printf replacement > mv-new && printf old > mv-existing && mv.exe mv-new mv-existing && cat.exe mv-existing && echo
replacement
```

```mooncram
$ printf retained-source > mv-retained && printf retained-target > mv-no-clobber && mv.exe -n mv-retained mv-no-clobber && cat.exe mv-retained mv-no-clobber && echo
retained-sourceretained-target
```

```mooncram
$ mkdir.exe mv-directory && printf a > mv-a && printf b > mv-b && mv.exe mv-a mv-b mv-directory && cat.exe mv-directory/mv-a mv-directory/mv-b && echo
ab
```

```mooncram
$ mkdir.exe -p mv-tree/sub && printf nested > mv-tree/sub/file && mv.exe mv-tree mv-tree-renamed && cat.exe mv-tree-renamed/sub/file && echo
nested
```

```mooncram
$ ln -s mv-existing mv-link && mv.exe mv-link mv-link-renamed && test -L mv-link-renamed && test ! -e mv-link && echo symlink-moved
symlink-moved
```

```mooncram
$ mkdir.exe -p mv-nested/sub && mv.exe mv-nested mv-nested/sub/new >/dev/null 2>&1
[1]
```

```mooncram
$ printf verbose > mv-verbose-source && mv.exe -v mv-verbose-source mv-verbose-target
renamed 'mv-verbose-source' -> 'mv-verbose-target'
```

```mooncram
$ mv.exe missing-mv-source mv-missing-target >/dev/null 2>&1
[1]
```

```mooncram
$ printf x > mv-t-one && printf y > mv-t-two && mv.exe -T mv-t-one mv-t-two mv-directory >/dev/null 2>&1
[1]
```

## rm

```mooncram
$ printf remove > rm-file && rm.exe rm-file && test ! -e rm-file && echo removed
removed
```

```mooncram
$ rm.exe missing-rm-file >/dev/null 2>&1
[1]
```

```mooncram
$ rm.exe -f missing-rm-file && rm.exe -f && echo force-ok
force-ok
```

```mooncram
$ mkdir.exe rm-directory && rm.exe rm-directory >/dev/null 2>&1
[1]
```

```mooncram
$ rm.exe -d rm-directory && test ! -e rm-directory && echo empty-dir-removed
empty-dir-removed
```

```mooncram
$ mkdir.exe -p rm-tree/sub && printf visible > rm-tree/file && printf hidden > rm-tree/.hidden && printf nested > rm-tree/sub/file && rm.exe -r rm-tree && test ! -e rm-tree && echo tree-removed
tree-removed
```

```mooncram
$ mkdir.exe rm-link-target && printf safe > rm-link-target/file && ln -s rm-link-target rm-directory-link && rm.exe -r rm-directory-link && test -d rm-link-target && cat.exe rm-link-target/file && echo
safe
```

```mooncram
$ mkdir.exe rm-protected && (cd rm-protected && rm.exe -r . >/dev/null 2>&1)
[1]
```

```mooncram
$ rm.exe --no-preserve-root anything >/dev/null 2>&1
[1]
```

```mooncram
$ printf verbose > rm-verbose && rm.exe -v rm-verbose
removed 'rm-verbose'
```

```mooncram
$ printf dash > ./-f && rm.exe -- ./-f && test ! -e ./-f && echo dash-removed
dash-removed
```

## rmdir

```mooncram
$ mkdir.exe rmdir-empty && rmdir.exe rmdir-empty && test ! -e rmdir-empty && echo empty-removed
empty-removed
```

```mooncram
$ mkdir.exe rmdir-nonempty && touch.exe rmdir-nonempty/file && rmdir.exe rmdir-nonempty >/dev/null 2>&1
[1]
```

```mooncram
$ rmdir.exe -I rmdir-nonempty && test.exe -d rmdir-nonempty && echo nonempty-ignored
nonempty-ignored
```

```mooncram
$ mkdir.exe -p rmdir-parents/a/b && rmdir.exe -p rmdir-parents/a/b && test ! -e rmdir-parents && echo parents-removed
parents-removed
```

```mooncram
$ mkdir.exe rmdir-verbose && rmdir.exe -v rmdir-verbose
rmdir: removed directory 'rmdir-verbose'
```

```mooncram
$ rmdir.exe cp-source >/dev/null 2>&1
[1]
```

## ln

```mooncram
$ ln.exe cp-source hard-link-unavailable >/dev/null 2>&1
[2]
```

```mooncram
$ printf linked > ln-source && ln.exe -s ln-source ln-link && cat.exe ln-link && echo
linked
```

```mooncram
$ ln.exe -s missing-ln-target dangling-link && ls.exe -dF dangling-link
dangling-link@
```

```mooncram
$ printf second > ln-second && ln.exe -sf ln-second ln-link && cat.exe ln-link && echo
second
```

```mooncram
$ mkdir.exe ln-directory && ln.exe -s ../ln-source ln-directory && cat.exe ln-directory/ln-source && echo
linked
```

```mooncram
$ ln.exe -sT ln-source ln-directory >/dev/null 2>&1
[1]
```

```mooncram
$ ln.exe -sT ln-source ln-second ln-directory >/dev/null 2>&1
[1]
```

```mooncram
$ mkdir.exe ln-protected-directory && ln.exe -sfT ln-source ln-protected-directory >/dev/null 2>&1
[1]
```

```mooncram
$ ln.exe -sv ln-source ln-verbose
'ln-verbose' -> 'ln-source'
```
