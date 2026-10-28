# Upstream Baselines

Updated: 2026-10-26

This file fixes the external behavior against which the workspace commands are
measured. A baseline is an oracle for tests, not a runtime dependency. Product
code remains pure MoonBit.

## Pinned Baselines

| Family | Baseline | Scope |
| --- | --- | --- |
| GNU Coreutils commands | GNU Coreutils 9.11 | `base32`, `base64`, `basename`, `cat`, `chmod`, `cksum`, `comm`, `cp`, `csplit`, `cut`, `date`, `dirname`, `echo`, `env`, `expand`, `expr`, `false`, `fmt`, `fold`, `head`, `join`, `ln`, `ls`, `md5sum`, `mkdir`, `mktemp`, `mv`, `nl`, `od`, `paste`, `printenv`, `printf`, `pwd`, `realpath`, `rm`, `rmdir`, `seq`, `sha1sum`, `sha256sum`, `sha512sum`, `sleep`, `sort`, `split`, `tac`, `tail`, `tee`, `test`, `timeout`, `touch`, `tr`, `true`, `unexpand`, `uniq`, `unlink`, `wc`, `yes` |
| GNU Diffutils | GNU Diffutils 3.12 | `cmp`, `diff` |
| GNU sed | GNU sed 4.9 | `sed` byte-profile scripts |
| GNU patch | GNU patch 2.8 | `patch` unified/context, offset/fuzz and mixed-reject profiles; existing-file writeback retains its metadata boundary |
| GNU gzip | GNU gzip 1.14 | `gzip`, `gunzip`, `zcat`; compare decoded data and failure behavior, not encoder byte identity |
| util-linux | util-linux 2.40 | `hexdump`, `column` and `rev`; selected C-byte layouts and errors |
| GNU Binutils | Binutils 2.44 | `strings` selected byte encodings, offsets and separators; no object-section compatibility claim |
| tree | tree 2.2.1 | `tree` selected traversal/text/JSON and safe HTML body comparisons; project page metadata is a separate contract |
| GNU findutils | GNU findutils 4.10.0 | `find`, `xargs` |
| GNU grep | GNU grep 3.12 | `grep`, with locale fixed to `LC_ALL=C` in the first conformance pass |
| ripgrep | Commit `3fce3b5bb0236da2df6d99672afb8a719642eca7` | `rg` explicit-path contracts; default Cargo features, locked dependencies, no `--features pcre2` build flag |
| GNU Wget | GNU Wget 1.25.0 | `wget`; the complete documented command is the target, with protocol families implemented in measured stages |
| curl | curl 8.22.0 | `curl`; the complete documented command is the target, with protocol families implemented in measured stages |
| POSIX shell | POSIX.1-2024 Shell Command Language, Dash 0.5.12 executable oracle | `sh`; the specification is authoritative and the pinned Dash build provides repeatable differential output; no Bash compatibility claim |
| GNU Make | GNU Make 4.4.1 | `make` |
| jq | jq 1.8.2 | `jq`, including its option and filter-language behavior |
| Vim `xxd` | Vim 9.1.0000 `xxd` | `xxd`; the oracle image pins the exact Vim tag archive and image digest |
| Imported `jqlog` source | `bobzhang/jqlog@0.1.0` at commit `06a529211343c773d30d2c3aa0231a2456665b7a` | `jqlog`; this is a source-snapshot migration baseline because there is no standard system command named `jqlog` |

`which` uses explicit PATH/access/PATHEXT contracts; this image does not build a
separate pinned GNU which executable. `jqlog`'s source label is provenance,
not an executable oracle. Neither a label nor a host PATH tool proves parity.

The Phase 0 image is built from
`ubuntu@sha256:2e863c44b718727c860746568e1d54afd13b2fa71b160f5cd9058fc436217b30`.
Every downloaded source or official binary is verified before use:

| Artifact | SHA-256 |
| --- | --- |
| `coreutils-9.11.tar.xz` | `394024eda0a5955217ceda9cd1201e65dc8fa3aa29c2951135a49521d57c3cc3` |
| `diffutils-3.12.tar.xz` | `7c8b7f9fc8609141fdea9cece85249d308624391ff61dedaf528fcb337727dfd` |
| `sed-4.9.tar.xz` | `6e226b732e1cd739464ad6862bd1a1aba42d7982922da7a53519631d24975181` |
| `patch-2.8.tar.xz` | `f87cee69eec2b4fcbf60a396b030ad6aa3415f192aa5f7ee84cad5e11f7f5ae3` |
| `gzip-1.14.tar.xz` | `01a7b881bd220bfdf615f97b8718f80bdfd3f6add385b993dcf6efd14e8c0ac6` |
| `util-linux-2.40.tar.xz` | `d57a626081f9ead02fa44c63a6af162ec19c58f53e993f206ab7c3a6641c2cd7` |
| `findutils-4.10.0.tar.xz` | `1387e0b67ff247d2abde998f90dfbf70c1491391a59ddfecb8ae698789f0a4f5` |
| `grep-3.12.tar.xz` | `2649b27c0e90e632eadcd757be06c6e9a4f48d941de51e7c0f83ff76408a07b9` |
| `wget-1.25.0.tar.gz` | `766e48423e79359ea31e41db9e5c289675947a7fcf2efdcedb726ac9d0da3784` |
| `make-4.4.1.tar.lz` | `8814ba072182b605d156d7589c19a43b89fc58ea479b9355146160946f8cf6e9` |
| `curl-8.22.0.tar.xz` | `f7ef3ae8a22e521f289803fe93543eb64c329b58aa73a9e224dfd915a2a5f4f7` |
| `dash-0.5.12.tar.gz` git snapshot | `0d632f6b945058d84809cac7805326775bd60cb4a316907d0bd4228ff7107154` |
| `jq-linux-amd64` 1.8.2 | `b1c22172dd303f3be49e935aa56aa48a8b7a46e0bc838b4997d3bb451495870f` |
| Vim `v9.1.0000.tar.gz` | `8d2a74e358be9cf260174e15e2e29dba4773f2670718b5bf728db6f54b90e25d` |
| `binutils-2.44.tar.xz` | `ce2017e059d63e67ddb9240e9d4ec49c2893605035cd60e92ad53177f4377237` |
| `tree-2.2.1.tgz` | `68ac45dc78c0c311ada06200ffc3c285e74223ba208061f8d15ffac25e44b2ec` |
| ripgrep commit archive | `e2c23831f1057a7e15575a72a64a900b317a86661561a786a36795717d602561` |
| `rust-1.97.1-x86_64-unknown-linux-gnu.tar.xz` | `88f28fa9af20594179f85d6df67078dfd6fa93e2f6da5e1e9b0ac4997988ca4f` |

The [Dockerfile](../tests/runner/image/Dockerfile) is the build authority; its
17 component stages are assembled in a fixed order. The table above records
the current pins, not the latest versions available upstream. Apt build/runtime
dependencies are not individually pinned by this recipe, so its base digest
and source hashes alone do not identify a finished executable image.

The checked-in [profile template](../tests/runner/image/profile.json) deliberately
has no final image digest or inventory. Linux development and manual acceptance
jobs pass the built content ID to [oracle.mbtx](../tests/oracle.mbtx), which
records the actual image, tool versions and source/recipe checksums in a fresh
run profile. [The verifier](../tests/testkit/oracle.mbt) binds that profile to
the reviewed recipe. The tag `mooncmd-oracle:phase0` is only a local build name;
an unsealed template or historical image ID is not current differential evidence.

A version, checksum, base-image digest, build option or recipe change requires
review and new comparisons; it must not silently change expected snapshots.

## Oracle Environment

The oracle runner sets:

- `LC_ALL=C` and `LANG=C` for byte/ordering compatibility;
- `TZ=UTC` for timestamp formatting;
- a controlled `PATH` containing only the pinned oracle tools and fixture
  helpers;
- an isolated temporary working directory per case;
- explicit stdin, stdout, stderr, cwd, and environment values;
- a fixed umask where the upstream command exposes permission-sensitive output.

Current workspace contracts live in [tests/cases](../tests/cases/) and are
selected by the [runtime index](../tests/registry/registry.json). Published
expectations use [latest-cases.json](../tests/release_runner/current/latest-cases.json)
with the exact coordinates in `latest.json`. Normalizations must be explicit;
binary streams otherwise compare without decoding or line-ending changes.

HTTP cases use `${HTTP_BASE}` placeholders and a deterministic
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

## Imported implementation provenance

The original twenty command modules came from `moonbit-community/moonbit-jq`
commit `06a529211343c773d30d2c3aa0231a2456665b7a` (2026-08-25): base64, cat,
comm, cut, false, head, join, jq, jqlog, nl, paste, printf, sleep, sort, tail,
tr, true, uniq, wc and xxd. Subsequent local command implementations remain
pure MoonBit; upstream executables serve only as test oracles.

The rg import pins rg.mbt 0.2.0 at
`2727c25819b00ddd1a0e9b24f9cb683931d64edf`. Its algorithms, generated Unicode/
encoding tables, author notices and package tests are retained in
[commands/rg](../commands/rg/). Large corpus data and CLI-equivalent printer
checks are integrated with the [shared test fixtures](../tests/fixtures/rg/README.md)
and contract runner, without changing their expectations. This source pin differs from the ripgrep semantic
oracle above. System access uses released public async APIs; compressed search
is deferred. The removed experiment and migration ledgers remain recoverable
from Git commit `65b4b7eea24c8215776c40721e1e00ad436268ce`.

Current shared dependencies are declared in [core/moon.mod](../core/moon.mod):
async 0.22.5, x 0.5.5, moonjq 0.2.0 and mooncry 0.95.0. Individual commands
retain their own published dependency coordinates. Source provenance and
dependency resolution do not themselves establish behavioral compatibility.

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

Links are references for behavior and option grammar. The exact executable
versions used by CI are authoritative for snapshots.
