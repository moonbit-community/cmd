# cmd

Command-line utilities implemented in pure MoonBit, running as Wasm through
MoonX on Linux, macOS and Windows.

Each published command is available as an independent `cli/<command>` module,
ready to use without building the entire repository.

## Features

- [x] Text processing: `cat`, `column`, `comm`, `cut`, `echo`, `expand`, `fmt`,
  `fold`, `grep`, `head`, `join`, `nl`, `paste`, `printf`, `rev`, `rg`, `sed`,
  `sort`, `tac`, `tail`, `tee`, `tr`, `unexpand`, `uniq`, and `wc`.
- [x] Comparison and splitting: `cmp`, `csplit`, `diff`, `patch`, and `split`.
- [x] Data and encoding: `base32`, `base64`, `hexdump`, `jq`, `jqlog`, `od`,
  `strings`, and `xxd`.
- [x] Files and paths: `basename`, `chmod`, `cp`, `dirname`, `find`, `ln`, `ls`,
  `mkdir`, `mktemp`, `mv`, `pwd`, `realpath`, `rm`, `rmdir`, `touch`, `tree`,
  and `unlink`.
- [x] Checksums and compression: `cksum`, `md5sum`, `sha1sum`, `sha256sum`,
  `sha512sum`, `gzip`, `gunzip`, and `zcat`.
- [x] Numbers and time: `date`, `expr`, `seq`, and `sleep`.
- [x] Environment and execution: `env`, `false`, `make`, `printenv`, `sh`,
  `test`, `true`, `which`, `xargs`, and `yes`.
- [x] Network and serving: `curl`, `wget`, and `serve`.
- [x] Typesetting: `typst`.

See each command's README for its supported behavior and limitations. The
project does not guarantee complete GNU/POSIX or upstream compatibility.
`timeout` is currently local-only and has not been published.

## Documentation

- [Command list and compatibility](docs/compatibility.md)
- [Development and testing](tests/README.md)
- [Design decisions](docs/adr/README.md)
- [Algorithms and performance](docs/performance/README.md)
- [Changelog](CHANGELOG.md)
