///|
priv struct FindTimeTest {
  comparison : Comparison
  reference : @fsops.FileTimestamp
  window : Int64
}

///|
fn parse_time_number(text : String) -> (Comparison, Double) raise FindError {
  let (comparison, raw) = parse_comparison(text)
  let (parsed, consumed, range_error) = @numfmt.parse_prefix(raw, Binary64)
  guard consumed > 0 && consumed == raw.length() && parsed is Finite(_, _, _) else {
    raise FindError("invalid finite time argument: '\{text}'")
  }
  let value = @string.parse_double(@numfmt.format_roundtrip(parsed, Binary64)) catch {
    _ => raise FindError("invalid finite time argument: '\{text}'")
  }
  // xstrtod accepts underflow to zero, but rejects a nonzero range error.
  if range_error && value != 0.0 {
    raise FindError("time argument out of range: '\{text}'")
  }
  (comparison, value)
}

///|
fn find_relative_timestamp(
  origin : @fsops.FileTimestamp,
  offset : Double,
  unit : Int64,
  text : String,
) -> @fsops.FileTimestamp raise FindError {
  let amount = offset * unit.to_double()
  let whole = amount.trunc()
  let fraction = (amount - whole) * 1000000000.0
  let seconds = origin.seconds.to_double() - whole
  // Reject nonfinite and out-of-range conversions instead of depending on
  // the undefined floating-to-time_t conversion of a particular C build.
  if amount.is_inf() ||
    seconds < -9223372036854775808.0 ||
    seconds >= 9223372036854775808.0 {
    raise FindError("time argument exceeds signed 64-bit seconds: '\{text}'")
  }
  let mut seconds = seconds.to_int64()
  let mut nanoseconds = (origin.nanoseconds.to_double() - fraction).to_int()
  if origin.nanoseconds.to_double() < fraction {
    if seconds == -9223372036854775808L {
      raise FindError("time argument exceeds signed 64-bit seconds: '\{text}'")
    }
    seconds -= 1L
    nanoseconds += 1000000000
  }
  // Keep GNU's one-way carry. A negative fractional offset can leave a
  // nanosecond field above one second; ordered comparisons use that field.
  { seconds, nanoseconds, }
}

///|
fn parse_time_test(
  text : String,
  now : @fsops.FileTimestamp,
  unit : Int64,
  used~ : Bool = false,
) -> FindTimeTest raise FindError {
  let (comparison, offset) = parse_time_number(text)
  let origin : @fsops.FileTimestamp = if used {
    { seconds: 0L, nanoseconds: 0, }
  } else if unit == 86400L {
    {
      ..now,
      seconds: now.seconds - (if comparison is Less { 1L } else { 86400L }),
    }
  } else {
    now
  }
  {
    comparison,
    reference: find_relative_timestamp(origin, offset, unit, text),
    window: unit,
  }
}

///|
fn find_seconds_difference(left : Int64, right : Int64) -> Int64? {
  if (right > 0L && left < -9223372036854775808L + right) ||
    (right < 0L && left > 9223372036854775807L + right) {
    None
  } else {
    Some(left - right)
  }
}

///|
fn FindTimeTest::matches(
  self : FindTimeTest,
  timestamp : @fsops.FileTimestamp,
) -> Bool {
  match self.comparison {
    Less => @fsops.compare_timestamps(timestamp, self.reference) > 0
    Greater => @fsops.compare_timestamps(timestamp, self.reference) < 0
    Exact => {
      guard find_seconds_difference(timestamp.seconds, self.reference.seconds)
        is Some(seconds) else {
        return false
      }
      let delta = seconds.to_double() +
        1.0e-9 *
        (
          timestamp.nanoseconds.to_double() -
          self.reference.nanoseconds.to_double()
        )
      delta > 0.0 && delta <= self.window.to_double()
    }
  }
}

///|
fn FindTimeTest::matches_used(
  self : FindTimeTest,
  accessed : @fsops.FileTimestamp,
  changed : @fsops.FileTimestamp,
) -> Bool raise FindError {
  if @fsops.compare_timestamps(accessed, changed) < 0 {
    return false
  }
  guard find_seconds_difference(changed.seconds, accessed.seconds)
    is Some(seconds) else {
    raise FindError("-used timestamp difference exceeds signed 64-bit seconds")
  }
  let nanoseconds = changed.nanoseconds - accessed.nanoseconds
  if nanoseconds < 0 {
    if seconds == -9223372036854775808L {
      raise FindError(
        "-used timestamp difference exceeds signed 64-bit seconds",
      )
    }
    self.matches({
      seconds: seconds - 1L,
      nanoseconds: nanoseconds + 1000000000,
    })
  } else {
    self.matches({ seconds, nanoseconds, })
  }
}
