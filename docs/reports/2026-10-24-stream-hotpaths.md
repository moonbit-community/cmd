# Copy, scan and count development observations

Date: 2026-10-24. Unpublished workspace implementation evidence.

Plain cat reuses a 64 KiB copy buffer. The shared line scanner retains the
unconsumed block instead of copying its tail for every record. Wc computes
only the selected counters and decodes UTF-8 only when required. Strings emits
an accepted printable run incrementally, retaining only a prefix shorter than
the requested minimum. Existing options and byte profiles remain unchanged.

The first three changes passed 112 complete output/status/stderr comparisons
on macOS arm64 with the unchanged PATH toolchain. Each arm received one warmup
and three measured fresh-process calls in alternating order. Direct Wasm
includes moonrun. Builds and other measurement children were stopped; ordinary
desktop applications remained open. The medians are:

| Workload | Before Native ms | After Native ms | Before Wasm ms | After Wasm ms |
| --- | ---: | ---: | ---: | ---: |
| cat, 8 MiB | 98.11 | 4.72 | 187.82 | 14.64 |
| wc -c, 8 MiB | 19.02 | 3.20 | 48.11 | 12.73 |
| wc -l, 8 MiB | 14.41 | 9.27 | 46.49 | 23.30 |
| wc default, 8 MiB | 14.78 | 9.78 | 46.12 | 31.19 |
| wc -m, 8 MiB | 14.74 | 5.36 | 45.60 | 18.45 |
| head, 1 MiB of two-byte records | 7992.55 | 6687.84 | 11128.24 | 10283.65 |
| head, one 512 KiB record | 3.55 | 2.71 | 14.00 | 12.40 |

The head results isolate the scanner change; output still performs per-record
writes in this checkpoint. They expose a separate output bottleneck rather
than establishing a fast head implementation. Raw observations and the pure
MoonBit observer are under `/private/tmp/cmd-copy-scan-count-observations-20261024/`
and `/private/tmp/cmd-copy-scan-count-observe-20261024.mbtx`.

The head output bottleneck is addressed separately with a shared 64 KiB writer.
New-file copying in fsops replaces the default 1 KiB transfer loop with a reused
64 KiB buffer, benefiting supported cp copies and mv copy fallbacks. Existing
preflight/replacement boundaries remain. A separate 64-call comparison passes
complete output/status/stderr and copy-byte checks with the same sampling method:

| Workload | Before Native ms | After Native ms | Before Wasm ms | After Wasm ms |
| --- | ---: | ---: | ---: | ---: |
| strings, short runs, 8 MiB | 3403.59 | 191.23 | 5090.97 | 460.97 |
| strings, one long run, 8 MiB | 22.12 | 10.86 | 129.31 | 67.29 |
| head, dense records, 64 KiB | 410.84 | 8.75 | 655.65 | 30.71 |
| cp, new file, 8 MiB | 100.74 | 5.18 | 192.69 | 17.22 |

Head's second baseline already includes the scanner change, isolating the writer.
These medians are not combined with the earlier head experiment. The second raw
report and observer are under `/private/tmp/cmd-more-hotpaths-20261024/`.

Strings passes four focused tests on each backend, including chunk-spanning
minimums, long runs, byte profiles, offsets and producer errors. Head/fsops pass
22 focused tests per backend, including preservation of completed output on
input failure and no replay after partial output failure. The eleven affected
command selection records 135 passing backend comparisons and two explicit
platform exclusions; those exclusions are not passing observations. These
results do not establish RSS, three-platform acceptance, published MoonX
performance or a new publication.

## External sort

Sort now prepares comparison transformations once, retaining stable sequence
IDs and prepared keys in disk runs. It uses a 64 MiB accounted run budget,
at most sixteen merge inputs, buffered output and an adjacent-record check
path. Catalog/help and release policy declare the temporary-write requirement.
A real default-budget spill under a read-only host policy returns status 1,
empty stdout and the host's file-write denial. The shared policy scenario retains
that regression alongside allowed small in-memory sorting. Existing options
remain. Nine focused tests pass on each backend,
including forced small-budget merge rounds, unique representatives, binary
records, input errors and truncated temporary records. Independent source
review found no actionable correctness defect.

A separate 32-call development comparison sorts 524,288 records of 32 bytes
(16 MiB). Even records plus entry bookkeeping exceed the default budget, so
the candidate spills; timing includes normal temporary I/O. Every call matches
the complete fixed GNU coreutils 9.11 output, status and stderr. Sampling uses
one warmup and three measured calls per arm in alternating order.

| Workload | Before Native ms | After Native ms | Before Wasm ms | After Wasm ms |
| --- | ---: | ---: | ---: | ---: |
| Default | 7014.07 | 474.26 | 10884.02 | 1172.03 |
| Folded second key, -k2,2f | 8215.80 | 1137.83 | 13952.71 | 2350.71 |

These compare the combined implementation; they do not isolate key caching
from buffering or temporary runs. Active/oversized records, unique-key storage
and runtime allocation overhead remain outside the accounted budget, so it is
not an RSS cap. Raw observations are under
`/private/tmp/cmd-sort-final-ab-20261024/`.
