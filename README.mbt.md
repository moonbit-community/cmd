# cmd

Command-line utilities implemented in pure MoonBit, running as Wasm through
MoonX on Linux, macOS and Windows.

Each published command is available as an independent `cli/<command>` module,
ready to use without building the entire repository.

## Features

- [x] Text processing: `awk`, `cat`, `column`, `comm`, `cut`, `echo`, `expand`, `fmt`,
  `fold`, `grep`, `head`, `join`, `nl`, `paste`, `printf`, `rev`, `rg`, `sed`,
  `sort`, `tac`, `tail`, `tee`, `tr`, `unexpand`, `uniq`, and `wc`.
- [x] Comparison and splitting: `cmp`, `csplit`, `diff`, `patch`, and `split`.
- [x] Data and encoding: `base32`, `base64`, `hexdump`, `jq`, `jqlog`, `od`,
  `strings`, and `xxd`.
- [x] Files and paths: `basename`, `chmod`, `cp`, `df`, `dirname`, `du`, `find`,
  `install`, `ln`, `ls`, `mkdir`, `mktemp`, `mv`, `pwd`, `readlink`, `realpath`,
  `rm`, `rmdir`, `stat`, `touch`, `tree`, `truncate`, and `unlink`.
- [x] Checksums and compression: `cksum`, `md5sum`, `sha1sum`, `sha256sum`,
  `sha512sum`, `gzip`, `gunzip`, `tar`, `unzip`, `zcat`, and `zip`.
- [x] System queries: `free`, `groups`, `hostname`, `id`, `nproc`, `ps`,
  `uname`, `uptime`, and `whoami`.
- [x] Terminal and signal queries: `clear`, `kill`, `tput`, and `tty`.
- [x] Numbers and time: `date`, `expr`, `seq`, and `sleep`.
- [x] Environment and execution: `env`, `false`, `make`, `printenv`, `sh`,
  `test`, `true`, `which`, `xargs`, and `yes`.
- [x] Network and serving: `curl`, `wget`, and `serve`.
- [x] Typesetting: `typst`.

`awk`, the new filesystem and archive commands, system queries, and terminal
commands are available in the workspace. See the [compatibility guide](docs/compatibility.md)
for platform and option coverage and the [published coordinates](tests/release/latest.json)
for registry availability.
`timeout` is currently local-only and has not been published.

## Documentation

- [Command list and compatibility](docs/compatibility.md)
- [Development and testing](tests/README.md)
- [Design decisions](docs/adr/README.md)
- [Algorithms and performance](docs/performance/README.md)
- [Changelog](CHANGELOG.md)
