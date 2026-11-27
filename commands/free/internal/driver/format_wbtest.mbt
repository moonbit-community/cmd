///|
test "wide memory report distinguishes available memory and reclaimable cache" {
  let snapshot = "MemTotal: 100 kB\nMemFree: 25 kB\nMemAvailable: 40 kB\nShmem: 5 kB\nCached: 20 kB\nSReclaimable: 4 kB\nBuffers: 2 kB\nSwapTotal: 10 kB\nSwapFree: 6 kB\n"
  assert_eq(
    report(snapshot, 1024L, true, true),
    "               total        used        free      shared     buffers       cache   available\nMem:             100          60          25           5           2          24          40\nSwap:             10           4           6\nTotal:           110          64          31\n",
  )
}
