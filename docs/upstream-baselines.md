# Upstream Baselines

This file fixes the external behavior against which the 48 commands are
measured. A baseline is an oracle for tests, not a runtime dependency. Product
code remains pure MoonBit.

## Pinned Baselines

| Family | Baseline | Scope |
| --- | --- | --- |
| GNU Coreutils commands | GNU Coreutils 9.11 | `base64`, `basename`, `cat`, `chmod`, `comm`, `cp`, `cut`, `dirname`, `echo`, `env`, `false`, `head`, `join`, `ln`, `ls`, `mkdir`, `mv`, `nl`, `paste`, `printenv`, `printf`, `pwd`, `rm`, `rmdir`, `seq`, `sha256sum`, `sleep`, `sort`, `tail`, `tee`, `test`, `timeout`, `touch`, `tr`, `true`, `uniq`, `wc` |
| GNU Diffutils | GNU Diffutils 3.12 | `cmp` |
| GNU findutils | GNU findutils 4.10.0 | `find`, `xargs` |
| GNU grep | GNU grep 3.12 | `grep`, with locale fixed to `LC_ALL=C` in the first conformance pass |
| GNU Wget | GNU Wget 1.25.0 | `wget`; the complete documented command is the target, with protocol families implemented in measured stages |
| curl | curl 8.22.0 | `curl`; the complete documented command is the target, with protocol families implemented in measured stages |
| POSIX shell | POSIX.1-2024 Shell Command Language, Dash 0.5.12 executable oracle | `sh`; the specification is authoritative and the pinned Dash build provides repeatable differential output; no Bash compatibility claim |
| GNU Make | GNU Make 4.4.1 | `make` |
| jq | jq 1.8.2 | `jq`, including its option and filter-language behavior |
| Vim `xxd` | Vim 9.1.0000 `xxd` | `xxd`; the oracle image pins the exact Vim tag archive and image digest |
| Imported `jqlog` source | `bobzhang/jqlog@0.1.0` at commit `06a529211343c773d30d2c3aa0231a2456665b7a` | `jqlog`; this is a source-snapshot migration baseline because there is no standard system command named `jqlog` |

The Phase 0 image is built from
`ubuntu@sha256:2e863c44b718727c860746568e1d54afd13b2fa71b160f5cd9058fc436217b30`.
Every downloaded source or official binary is verified before use:

| Artifact | SHA-256 |
| --- | --- |
| `coreutils-9.11.tar.xz` | `394024eda0a5955217ceda9cd1201e65dc8fa3aa29c2951135a49521d57c3cc3` |
| `diffutils-3.12.tar.xz` | `7c8b7f9fc8609141fdea9cece85249d308624391ff61dedaf528fcb337727dfd` |
| `findutils-4.10.0.tar.xz` | `1387e0b67ff247d2abde998f90dfbf70c1491391a59ddfecb8ae698789f0a4f5` |
| `grep-3.12.tar.xz` | `2649b27c0e90e632eadcd757be06c6e9a4f48d941de51e7c0f83ff76408a07b9` |
| `wget-1.25.0.tar.gz` | `766e48423e79359ea31e41db9e5c289675947a7fcf2efdcedb726ac9d0da3784` |
| `make-4.4.1.tar.lz` | `8814ba072182b605d156d7589c19a43b89fc58ea479b9355146160946f8cf6e9` |
| `curl-8.22.0.tar.xz` | `f7ef3ae8a22e521f289803fe93543eb64c329b58aa73a9e224dfd915a2a5f4f7` |
| `dash-0.5.12.tar.gz` git snapshot | `0d632f6b945058d84809cac7805326775bd60cb4a316907d0bd4228ff7107154` |
| `jq-linux-amd64` 1.8.2 | `b1c22172dd303f3be49e935aa56aa48a8b7a46e0bc838b4997d3bb451495870f` |
| Vim `v9.1.0000.tar.gz` | `8d2a74e358be9cf260174e15e2e29dba4773f2670718b5bf728db6f54b90e25d` |

The `pinned-upstream-oracle` CI job prints every tool version, the built image
content ID, and uploads both as build evidence. A version, checksum, base-image
digest, or build recipe change opens a baseline update review; it must not
silently change expected snapshots.

## Oracle Environment

The oracle runner sets:

- `LC_ALL=C` and `LANG=C` for byte/ordering compatibility;
- `TZ=UTC` for timestamp formatting;
- a controlled `PATH` containing only the pinned oracle tools and fixture
  helpers;
- an isolated temporary working directory per case;
- explicit stdin, stdout, stderr, cwd, and environment values;
- a fixed umask where the upstream command exposes permission-sensitive output.

The seed contract is `tests/fixtures/oracle/cases.json`. Its normalization list
is empty unless a fixture explicitly names a supported text field, rule, and
rationale. Binary streams are otherwise compared without decoding or
line-ending changes.

Phase 2 HTTP cases use `${HTTP_BASE}` placeholders and a deterministic
pure-MoonBit fixture server. The runner expands the placeholder for both the
candidate and pinned Linux container and enables host networking only for
those cases; all other oracle containers remain `--network none`. HTTP oracle
cases run in a dedicated fixture-server process so the synchronous candidate
and Docker subprocess waits cannot starve the server event loop.
Self-signed HTTPS cases use `${HTTPS_BASE}` and a test-only OpenSSL fixture
process on the Linux CI host; both candidate and pinned container receive the
same endpoint and explicitly select their insecure/certificate-bypass option.

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
