///|
test "benchmark schedule has five warmups and balanced alternating measured pairs" {
  let plan = sampling_plan()
  assert_eq(plan.warmups.length(), 5)
  assert_eq(plan.pairs.length(), 105)
  assert_eq(plan.bootstrap_iterations, 10000)
  assert_eq(plan.bootstrap_seed.length(), 32)
  let orders = plan.warmups.copy()
  orders.append(plan.pairs.map(pair => pair.order))
  for index in 1..<orders.length() {
    assert_true(
      (orders[index] is CandidateFirst) != (orders[index - 1] is CandidateFirst),
    )
  }
  assert_eq(
    plan.pairs.filter(pair => pair.order is CandidateFirst).length(),
    53,
  )
  assert_eq(plan.pairs.filter(pair => pair.order is UpstreamFirst).length(), 52)
  for block in 0..<5 {
    assert_eq(plan.pairs.filter(pair => pair.block == block).length(), 21)
    assert_true(
      (plan.pairs[block * 21].order is CandidateFirst) == (block % 2 == 0),
    )
  }
  for index, pair in plan.pairs {
    assert_eq(pair.index, index)
    assert_true((pair.order is CandidateFirst) == (index % 2 == 0))
  }
}

///|
test "benchmark quantiles freeze even median p95 and percentile endpoints" {
  assert_eq(median([9.0, 1.0, 5.0, 3.0]), 4.0)
  assert_eq(median([@double.max_value, @double.max_value]), @double.max_value)
  assert_eq(
    median([@double.min_positive, @double.min_positive]),
    @double.min_positive,
  )
  let values = Array::makei(105, index => (index + 1).to_double())
  let summary = side_statistics(values)
  assert_eq(summary.median_us, 53.0)
  assert_eq(summary.p95_us, 100.0)
  assert_eq(summary.mad_us, 26.0)
  let estimates = Array::makei(10000, index => (index + 1).to_double())
  assert_eq(percentile_sorted(estimates, 25, 1000), 250.0)
  assert_eq(percentile_sorted(estimates, 975, 1000), 9750.0)
  assert_eq(values[0], 1.0)
}

///|
test "benchmark bootstrap resamples pairs and uses ratio of medians" {
  assert_eq(ratio_of_medians([1.0, 100.0, 101.0], [1.0, 1.0, 100.0]), 100.0)
  assert_eq(median([1.0, 100.0, 1.01]), 1.01)
  let correlated = Array::makei(5, index => {
    let upstream = (index + 1).to_double()
    { candidate_us: upstream * 2.0, upstream_us: upstream, }
  })
  let scaled = bootstrap_interval(correlated)
  assert_eq(scaled.lower, 2.0)
  assert_eq(scaled.upper, 2.0)
  let samples : Array[PairedSample] = [
    { candidate_us: 1.0, upstream_us: 1.0, },
    { candidate_us: 100.0, upstream_us: 1.0, },
    { candidate_us: 101.0, upstream_us: 100.0, },
  ]
  let first = bootstrap_interval(samples)
  let repeated = bootstrap_interval(samples)
  assert_eq(first.lower, 1.0)
  assert_eq(first.upper, 100.0)
  assert_eq(first.lower, repeated.lower)
  assert_eq(first.upper, repeated.upper)
}

///|
test "benchmark complete row accepts inclusive delivery threshold" {
  let samples : Array[PairedSample] = Array::make(105, {
    candidate_us: 30.0,
    upstream_us: 10.0,
  })
  let row = summarize_row(samples, correctness_ok=true)
  assert_true(row.verdict is Pass)
  assert_eq(row.reasons, [])
  let summary = row.statistics.unwrap()
  assert_eq(summary.r50, 3.0)
  assert_eq(summary.r95, 3.0)
  assert_eq(summary.r50_interval95.lower, 3.0)
  assert_eq(summary.r50_interval95.upper, 3.0)
}

///|
test "benchmark p95 failure cannot be hidden by a passing median" {
  let samples : Array[PairedSample] = Array::makei(105, index => {
    candidate_us: if index >= 99 {
      40.0
    } else {
      10.0
    },
    upstream_us: 10.0,
  })
  let row = summarize_row(samples, correctness_ok=true)
  assert_true(row.verdict is Fail)
  let summary = row.statistics.unwrap()
  assert_eq(summary.r50, 1.0)
  assert_eq(summary.r95, 4.0)
  assert_true(row.reasons.contains("R95 exceeds 3.0"))
}

///|
test "benchmark interval upper bound can reject passing median and p95 ratios" {
  let samples : Array[PairedSample] = Array::makei(105, index => {
    candidate_us: 300.0,
    upstream_us: if index < 52 {
      90.0
    } else {
      100.0
    },
  })
  let row = summarize_row(samples, correctness_ok=true)
  assert_true(row.verdict is Fail)
  let summary = row.statistics.unwrap()
  assert_eq(summary.r50, 3.0)
  assert_eq(summary.r95, 3.0)
  assert_eq(summary.r50_interval95.upper, 300.0 / 90.0)
  assert_eq(row.reasons, ["R50 95% upper endpoint exceeds 3.0"])
}

///|
test "benchmark noise checks both sides and exact MAD and block drift limits" {
  let at_mad_limit = side_statistics(
    Array::makei(105, index => 9.5 + (index % 3).to_double() * 0.5),
  )
  assert_eq(at_mad_limit.mad_us, 0.5)
  assert_false(at_mad_limit.noisy)
  let at_drift_limit = side_statistics(
    Array::makei(105, index => [9.5, 10.0, 10.0, 10.0, 10.5][index / 21]),
  )
  assert_eq(at_drift_limit.block_drift, 0.10)
  assert_false(at_drift_limit.noisy)
  let drifting = side_statistics(
    Array::makei(105, index => [9.0, 10.0, 10.0, 10.0, 11.0][index / 21]),
  )
  assert_eq(drifting.mad_us, 0.0)
  assert_eq(drifting.block_drift, 0.20)
  assert_true(drifting.noisy)
  let samples : Array[PairedSample] = Array::makei(105, index => {
    candidate_us: 5.0,
    upstream_us: 9.0 + (index % 3).to_double(),
  })
  let row = summarize_row(samples, correctness_ok=true)
  assert_true(row.verdict is Inconclusive)
  assert_eq(row.reasons, ["upstream samples are noisy"])
  let reversed = summarize_row(
    samples.map(pair => {
      candidate_us: pair.upstream_us / 2.0,
      upstream_us: 10.0,
    }),
    correctness_ok=true,
  )
  assert_true(reversed.verdict is Inconclusive)
  assert_eq(reversed.reasons, ["candidate samples are noisy"])
}

///|
test "benchmark missing failed and invalid observations never pass" {
  assert_true(summarize_row([], correctness_ok=true).verdict is Inconclusive)
  assert_true(summarize_row([], correctness_ok=false).verdict is Fail)
  for duration in [0.0, -1.0, @double.infinity, @double.not_a_number] {
    let samples : Array[PairedSample] = Array::make(105, {
      candidate_us: duration,
      upstream_us: 10.0,
    })
    let row = summarize_row(samples, correctness_ok=true)
    assert_true(row.verdict is Fail)
    assert_true(row.statistics is None)
  }
  let overflow : Array[PairedSample] = Array::make(105, {
    candidate_us: @double.max_value,
    upstream_us: @double.min_positive,
  })
  let row = summarize_row(overflow, correctness_ok=true)
  assert_true(row.verdict is Fail)
  assert_eq(row.reasons, ["duration ratio overflowed or underflowed"])
}
