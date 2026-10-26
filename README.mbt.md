# cmd

Pure-MoonBit command-line utilities delivered as Wasm through MoonX. Each published
command is an independent `cli/<command>` MoonX module. The support listed here
is a measured subset of the corresponding upstream command; it does not claim
complete GNU/POSIX compatibility. See the [support record](docs/compatibility.md)
for exact versions, observed behavior and boundaries.

Development acceptance runs current Wasm commands on Linux, macOS and Windows.
Native is used for test tools. Resource observations and exact-version MoonX
acceptance have separate manual workflows; see [tests](tests/README.md).

## Features

- [x] Text, data and archives: `base32`, `base64`, `cat`, `cksum`, `cmp`,
  `column`, `comm`, `cut`, `date`, `diff`, `echo`, `expand`, `expr`, `fmt`,
  `fold`, `grep`, `gunzip`, `gzip`, `head`, `hexdump`, `join`, `jq`, `jqlog`,
  `md5sum`, `nl`, `od`, `paste`, `printf`, `rev`, `sed`, `seq`, `sha1sum`,
  `sha256sum`, `sha512sum`, `sort`, `strings`, `tac`, `tail`, `tr`, `uniq`,
  `wc`, `xxd`, and `zcat`.
- [x] Files and paths: `basename`, `chmod`, `cp`, `csplit`, `dirname`, `find`,
  `ln`, `ls`, `mkdir`, `mktemp`, `mv`, `patch`, `realpath`, `rm`, `rmdir`,
  `split`, `tee`, `touch`, `tree`, `unexpand`, and `unlink`.
- [x] Environment, execution and network: `curl`, `env`, `false`, `make`,
  `printenv`, `pwd`, `sh`, `sleep`, `test`, `true`, `wget`, `which`, `xargs`,
  and `yes`.
- [ ] Planned command modules: `awk`, `chgrp`, `chown`, `clear`, `df`, `du`,
  `free`, `groups`, `hostname`, `id`, `install`, `kill`, `link`, `nproc`,
  `ps`, `readlink`, `stat`, `stty`, `tar`, `truncate`, `tput`, `tty`, `uname`,
  `unzip`, `uptime`, `watch`, `whoami`, and `zip`. These are planned work only;
  no published module or support claim exists for them yet.

The `timeout` package is local-only while a portable public process-group
interface is unavailable. Its status is recorded in the support record and it
is not a published MoonX feature.

Every workspace command also follows one metadata contract: standalone
`--help` prints usage and exits 0, while standalone `--version` prints
`<command> <package-version>` and exits 0. Both paths leave
stdin untouched. The current Native and Wasm regressions pass all 79 workspace
commands; published coordinates are promoted only through the release and
exact MoonX checks described in the support record.
