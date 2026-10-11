# cli/core

Shared runtime packages used by the independently published command modules.
The local **0.4.0 candidate** adds catalog contracts for `strings`, `column`,
`which` and `date` on top of the shared incremental MD5/SHA-1/SHA-512,
C-byte regular-expression adaptation and gzip stream codecs. Published core
0.3.0 remains available for unchanged command packages.
This module is published as `cli/core` and is an implementation dependency for
`cli/<command>` modules. The portable filesystem layer exposes file-kind and
regular-file-size reads, atime/mtime/ctime timestamps, access checks, and
symbolic-link creation on Native/Wasm. It also centralizes nanosecond comparison,
age buckets, update/backup decisions, and preflighted copy traversal. Permission
reads, arbitrary timestamp setters, hard links, readlink, special-file creation,
remain unavailable in public async 0.22.4. POSIX EXDEV classification uses the
actual host platform; it does not provide metadata-preserving cross-device
copying. Existing-file copy overwrite is rejected, and new-file copying must
explicitly select `--no-preserve=mode`.
