///|
priv enum PairOrder {
  CandidateFirst
  UpstreamFirst
} derive(ToJson)

///|
priv struct ScheduledPair {
  index : Int32
  block : Int32
  order : PairOrder
} derive(ToJson)

///|
priv struct SamplingPlan {
  warmups : Array[PairOrder]
  pairs : Array[ScheduledPair]
  bootstrap_seed : Bytes
  bootstrap_iterations : Int32
} derive(ToJson)

///|
fn sampling_plan() -> SamplingPlan {
  {
    warmups: Array::makei(5, pair_order),
    pairs: Array::makei(105, index => {
      index,
      block: index / 21,
      order: pair_order(index),
    }),
    bootstrap_seed: b"0123456789abcdef0123456789abcdef",
    bootstrap_iterations: 10000,
  }
}

///|
fn pair_order(index : Int32) -> PairOrder {
  if index % 2 == 0 {
    CandidateFirst
  } else {
    UpstreamFirst
  }
}

///|
priv struct PairedSample {
  candidate_us : Double
  upstream_us : Double
} derive(ToJson)

///|
priv struct SideStatistics {
  median_us : Double
  p95_us : Double
  mad_us : Double
  block_medians_us : Array[Double]
  block_drift : Double
  noisy : Bool
} derive(ToJson)

///|
priv struct RatioInterval {
  lower : Double
  upper : Double
} derive(ToJson)

///|
priv struct RowStatistics {
  candidate : SideStatistics
  upstream : SideStatistics
  r50 : Double
  r95 : Double
  r50_interval95 : RatioInterval
} derive(ToJson)

///|
priv enum RowVerdict {
  Pass
  Fail
  Inconclusive
} derive(ToJson)

///|
priv struct RowResult {
  verdict : RowVerdict
  statistics : RowStatistics?
  reasons : Array[String]
} derive(ToJson)

///|
fn finite_positive(value : Double) -> Bool {
  value > 0.0 && !value.is_inf()
}

///|
fn median_sorted(values : Array[Double]) -> Double {
  let middle = values.length() / 2
  if values.length() % 2 == 1 {
    values[middle]
  } else {
    // Sorted nonnegative values avoid both sum overflow and halving underflow.
    let lower = values[middle - 1]
    lower + (values[middle] - lower) / 2.0
  }
}

///|
fn median(values : Array[Double]) -> Double {
  let sorted = values.copy()
  sorted.sort()
  median_sorted(sorted)
}

///|
// All percentiles use nearest rank, with no interpolation. For 10,000
// bootstrap estimates the 2.5/97.5 endpoints are elements 250 and 9750.
fn percentile_sorted(
  sorted : Array[Double],
  numerator : Int32,
  denominator : Int32,
) -> Double {
  sorted[(sorted.length() * numerator + denominator - 1) / denominator - 1]
}

///|
fn side_statistics(values : Array[Double]) -> SideStatistics {
  let sorted = values.copy()
  sorted.sort()
  let median_us = median_sorted(sorted)
  let mad_us = median(values.map(value => (value - median_us).abs()))
  let block_medians_us = Array::makei(5, block => {
    median(Array::makei(21, index => values[block * 21 + index]))
  })
  let sorted_blocks = block_medians_us.copy()
  sorted_blocks.sort()
  let block_drift = (sorted_blocks[4] - sorted_blocks[0]) / median_us
  {
    median_us,
    p95_us: percentile_sorted(sorted, 95, 100),
    mad_us,
    block_medians_us,
    block_drift,
    noisy: mad_us / median_us > 0.05 || block_drift > 0.10,
  }
}

///|
fn ratio_of_medians(
  candidate : Array[Double],
  upstream : Array[Double],
) -> Double {
  median(candidate) / median(upstream)
}

///|
fn bootstrap_interval(samples : Array[PairedSample]) -> RatioInterval {
  let plan = sampling_plan()
  let random = @random.Rand::chacha8(seed=plan.bootstrap_seed)
  let candidate = Array::make(samples.length(), 0.0)
  let upstream = Array::make(samples.length(), 0.0)
  let estimates = Array::makei(plan.bootstrap_iterations, _ => {
    for index in 0..<samples.length() {
      let pair = samples[random.int(limit=samples.length())]
      candidate[index] = pair.candidate_us
      upstream[index] = pair.upstream_us
    }
    ratio_of_medians(candidate, upstream)
  })
  estimates.sort()
  {
    lower: percentile_sorted(estimates, 25, 1000),
    upper: percentile_sorted(estimates, 975, 1000),
  }
}

///|
/// Samples retain measured pair order; warmups are not included. Correctness
/// includes both executions and their output/effect checks, outside timing.
fn summarize_row(
  samples : Array[PairedSample],
  correctness_ok~ : Bool,
) -> RowResult {
  if !correctness_ok {
    return {
      verdict: Fail,
      statistics: None,
      reasons: ["execution or correctness check failed"],
    }
  }
  if samples.length() != 105 {
    return {
      verdict: Inconclusive,
      statistics: None,
      reasons: ["requires 105 complete measured pairs"],
    }
  }
  if samples.any(pair => {
      !finite_positive(pair.candidate_us) || !finite_positive(pair.upstream_us)
    }) {
    return {
      verdict: Fail,
      statistics: None,
      reasons: ["duration must be finite and positive"],
    }
  }
  let candidate = side_statistics(samples.map(pair => pair.candidate_us))
  let upstream = side_statistics(samples.map(pair => pair.upstream_us))
  let r50 = candidate.median_us / upstream.median_us
  let r95 = candidate.p95_us / upstream.p95_us
  let interval = bootstrap_interval(samples)
  if ![r50, r95, interval.lower, interval.upper].all(finite_positive) {
    return {
      verdict: Fail,
      statistics: None,
      reasons: ["duration ratio overflowed or underflowed"],
    }
  }
  let reasons : Array[String] = []
  if r50 > 3.0 {
    reasons.push("R50 exceeds 3.0")
  }
  if r95 > 3.0 {
    reasons.push("R95 exceeds 3.0")
  }
  if interval.upper > 3.0 {
    reasons.push("R50 95% upper endpoint exceeds 3.0")
  }
  let failed = !reasons.is_empty()
  if candidate.noisy {
    reasons.push("candidate samples are noisy")
  }
  if upstream.noisy {
    reasons.push("upstream samples are noisy")
  }
  {
    verdict: if failed {
      Fail
    } else if candidate.noisy || upstream.noisy {
      Inconclusive
    } else {
      Pass
    },
    statistics: Some({
      candidate,
      upstream,
      r50,
      r95,
      r50_interval95: interval,
    }),
    reasons,
  }
}
