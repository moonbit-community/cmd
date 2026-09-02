# Upstream Baselines

This file fixes the external behavior against which the 48 commands are
measured. A baseline is an oracle for tests, not a runtime dependency. Product
code remains pure MoonBit.

## Pinned Baselines

| Family | Baseline | Scope |
| --- | --- | --- |
| GNU Coreutils commands | GNU Coreutils 9.11 | `base64`, `basename`, `cat`, `chmod`, `cmp`, `comm`, `cp`, `cut`, `dirname`, `echo`, `env`, `false`, `head`, `join`, `ln`, `ls`, `mkdir`, `mv`, `nl`, `paste`, `printenv`, `printf`, `pwd`, `rm`, `rmdir`, `seq`, `sha256sum`, `sleep`, `sort`, `tail`, `tee`, `test`, `timeout`, `touch`, `tr`, `true`, `uniq`, `wc` |
| GNU findutils | GNU findutils 4.10.0 | `find`, `xargs` |
| GNU grep | GNU grep 3.12 | `grep`, with locale fixed to `LC_ALL=C` in the first conformance pass |
| GNU Wget | GNU Wget 1.25.0 | `wget`; the complete documented command is the target, with protocol families implemented in measured stages |
| curl | curl 8.22.0 | `curl`; the complete documented command is the target, with protocol families implemented in measured stages |
| POSIX shell | POSIX.1-2024 Shell Command Language | `sh`; no Bash compatibility claim |
| GNU Make | GNU Make 4.4.1 | `make` |
| jq | jq 1.8.2 | `jq`, including its option and filter-language behavior |
| Vim `xxd` | Vim 9.1 `xxd` | `xxd`; the oracle image additionally pins the exact Vim patch build and image digest |
| Imported `jqlog` source | `bobzhang/jqlog@0.1.0` at commit `06a529211343c773d30d2c3aa0231a2456665b7a` | `jqlog`; this is a source-snapshot migration baseline because there is no standard system command named `jqlog` |

The image used in Phase 0 must print every tool version and publish its digest
in CI. A version change opens a baseline update review; it must not silently
change expected snapshots.

## Oracle Environment

The oracle runner sets:

- `LC_ALL=C` and `LANG=C` for byte/ordering compatibility;
- `TZ=UTC` for timestamp formatting;
- a controlled `PATH` containing only the pinned oracle tools and fixture
  helpers;
- an isolated temporary working directory per case;
- explicit stdin, stdout, stderr, cwd, and environment values;
- a fixed umask where the upstream command exposes permission-sensitive output.

The runner compares exit status, stdout, stderr, filesystem entries, file
bytes, selected metadata, and child-process observations. It may normalize only
temporary paths, platform-specific path separators, and explicitly declared
time fields. Each normalization has a fixture proving that it does not hide a
semantic difference.

## Reference Manuals

- [GNU Coreutils 9.11](https://www.gnu.org/software/coreutils/manual/coreutils.html)
- [GNU findutils 4.10.0](https://www.gnu.org/software/findutils/manual/html_mono/find.html)
- [GNU grep 3.12](https://www.gnu.org/software/grep/manual/grep.html)
- [GNU Wget 1.25.0](https://www.gnu.org/software/wget/manual/wget.html)
- [curl 8.22.0](https://curl.se/docs/manpage.html)
- [POSIX.1-2024 Shell Command Language](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html)
- [GNU Make 4.4.1](https://www.gnu.org/software/make/manual/make.html)
- [jq 1.8.2 manual](https://jqlang.org/manual/v1.8/)
- [Vim `xxd` help](https://vimhelp.org/xxd.txt.html)
- [Imported command provenance](provenance.md)

Links are references for behavior and option grammar. The exact executable
versions used by CI are authoritative for snapshots.
