///|
test "diagnostic probes cannot qualify incomplete noisy or invalid samples" {
  assert_eq(probe_pairs(Map([])), 0)
  for bad in ["0", "2", "4", "107", "not-a-number"] {
    let rejected = probe_pairs(Map([("--probe-pairs", bad)])) catch { _ => -1 }
    assert_eq(rejected, -1)
  }
  let samples : Array[PairedSample] = Array::make(9, {
    candidate_us: 20.0,
    upstream_us: 10.0,
  })
  assert_true(
    probe_summary(samples, 9, true)
    is { "passed": True, "ratio": Number(2.0, ..), .. },
  )
  for
    result in [
      probe_summary([], 9, true),
      probe_summary(samples, 11, true),
      probe_summary(samples, 9, false),
      probe_summary(
        samples.map(pair => { ..pair, candidate_us: 0.0, }),
        9,
        true,
      ),
      probe_summary(
        Array::makei(9, i => {
          candidate_us: 20.0,
          upstream_us: [1.0, 10.0, 100.0][i % 3],
        }),
        9,
        true,
      ),
    ] {
    assert_true(result is { "passed": False, .. })
  }
}
