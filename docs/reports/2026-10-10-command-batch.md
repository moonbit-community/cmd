# 2026-10-10 command candidate batch

This report covers sixteen pure MoonBit candidates: fold, od, hexdump, md5sum,
sha1sum, sha512sum, sed, diff, patch, split, csplit, expr, fmt, gzip, gunzip,
and zcat. Each command starts at 0.1.0. Shared byte-regex, checksum and gzip
packages expand the core API, so core is prepared as 0.3.0. Previously published
command versions and frozen manifests are unchanged. No package in this batch
has been published by this report.

Baseline: Moon 0.1.20260920, compiler/core 0.10.14+7d59c7ec9,
async 0.22.4, x 0.5.5, moonjq 0.1.2. No project FFI or host-command fallback.

Local validation completed on 2026-10-11. Package tests passed with 229 Native
and 198 Wasm tests. The unified runner passed 436 semantic command contracts
on each backend, plus the declared boundary cases; Native and Wasm scenarios
passed 5/5, and the Wasm policy boundary passed. These are workspace results;
they do not establish remote CI or published-consumer acceptance.

The active command contracts live in tests/cases/<command>.json. Package tests
cover hash block/padding boundaries, edit reconstruction, parser behavior,
DEFLATE blocks, sliding-window overlap and partial-error bytes. Independent
oracle scripts accompany this report. Fixed upstream comparisons passed:
fold/od/hexdump 380/380 (coreutils 9.11 and util-linux 2.40), diff 143/143
(diffutils 3.12), fmt 96/96 (coreutils 9.11), gzip 54/54 (gzip 1.14), and
patch 6/6 (patch 2.8). Boundary cases remain recorded separately and are not
promoted to upstream compatibility.

Known explicit limits: existing-output split/csplit needs safe handle
truncation; patch writeback needs source mode preservation; named gzip
replacement needs metadata; unsupported regex, sed grammar, diff recursion,
fmt margin modes and compression levels remain project work. See canonical
ADR-0004/0008/0009 and docs/async-upstream-gaps.md for alternatives and unlock
conditions. A present command module is not full GNU/POSIX compatibility.

The final probe programs are `docs/reports/2026-10-10-*-oracle.mbtx` and
`docs/reports/2026-10-11-patch-oracle.mbtx`; their output files retain the
exact tool versions and comparison counts. Remote Linux/macOS/Windows CI and
the first registry publication are still release gates.
