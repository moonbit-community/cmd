# Gzip decoder buffer reuse and block copies

The output ring now retains backreference history after each full flush.
This removes a separate 32 KiB byte array, its cursor and a second store for
each decoded byte. The maximum DEFLATE distance remains 32 KiB. Test-only
decoding uses the same ring while suppressing sink writes. No public API,
compression format or command option changed.

Stored chunks use a bulk byte copy. Backreferences copy forward to preserve
overlap. Both paths keep CRC in a local value and update output size, history
length and the output cursor once per chunk instead of once per byte.

Native and Wasm each pass the existing 30 codec regressions, including the
extended 100,000-byte test-only wrap check. Four fixed GNU level-six streams
also decode to every original byte on both backends. Existing error-prefix,
one-byte-feed and failed-writer regressions remain green.

Two development comparisons run on macOS arm64. The first isolates the output
ring against accepted G2; the second isolates block copying against that ring
alone. Each arm receives one warmup and three measured fresh-process calls in
rotating order. Both sets of 60 calls pass complete output,
status and stderr checks. Builds, VMs and other benchmark children were stopped;
ordinary desktop applications remained open. The toolchain is the unchanged
20261021 PATH installation. Direct Wasm includes moonrun.

The second comparison is:

| 8 MiB decoded corpus | Ring-only Native ms | Final Native ms | Ring-only Wasm ms | Final Wasm ms |
| --- | ---: | ---: | ---: | ---: |
| Repeated record | 35.32 | 23.56 | 61.87 | 52.59 |
| Repeated 32,000-byte block | 38.89 | 27.25 | 84.10 | 65.52 |
| Entropy | 30.56 | 19.66 | 49.33 | 34.57 |

The first comparison improves Wasm medians approximately 10–19%; Native ranges
from 0.6% slower to 6.3% faster. Block copying then improves Native medians
30–36% and Wasm 15–30% in its own control. The eliminated allocation is an explicit
storage saving, not a measured RSS claim. These development observations do not
establish the 105-pair published MoonX performance gate or a new publication.
Raw trials, byte comparisons and the reused pure MoonBit observer are retained
under `/private/tmp/cmd-gzip-hotpaths-20261024/`.
