///|
/// Summary statistics produced at the end of a search.
///
/// Durations are represented as `Int64` nanoseconds.
pub struct Stats {
  priv mut elapsed : Int64
  priv mut searches : Int64
  priv mut searches_with_match : Int64
  priv mut bytes_searched : Int64
  priv mut bytes_printed : Int64
  priv mut matched_lines : Int64
  priv mut matches : Int64
} derive(Eq, Debug)

///|
/// Return a new value for tracking aggregate statistics across searches.
/// All statistics are set to `0`.
pub fn Stats::new() -> Stats {
  {
    elapsed: 0,
    searches: 0,
    searches_with_match: 0,
    bytes_searched: 0,
    bytes_printed: 0,
    matched_lines: 0,
    matches: 0,
  }
}

///|
pub fn Stats::clone(self : Stats) -> Stats {
  { ..self, }
}

///|
/// Return the total amount of time elapsed, in nanoseconds.
pub fn Stats::elapsed(self : Stats) -> Int64 {
  self.elapsed
}

///|
/// Return the total number of searches executed.
pub fn Stats::searches(self : Stats) -> Int64 {
  self.searches
}

///|
/// Return the total number of searches that found at least one match.
pub fn Stats::searches_with_match(self : Stats) -> Int64 {
  self.searches_with_match
}

///|
/// Return the total number of bytes searched.
pub fn Stats::bytes_searched(self : Stats) -> Int64 {
  self.bytes_searched
}

///|
/// Return the total number of bytes printed.
pub fn Stats::bytes_printed(self : Stats) -> Int64 {
  self.bytes_printed
}

///|
/// Return the total number of lines that participated in a match.
pub fn Stats::matched_lines(self : Stats) -> Int64 {
  self.matched_lines
}

///|
/// Return the total number of matches.
pub fn Stats::matches(self : Stats) -> Int64 {
  self.matches
}

///|
/// Add to the elapsed time (in nanoseconds).
pub fn Stats::add_elapsed(self : Stats, nanos : Int64) -> Unit {
  self.elapsed += nanos
}

///|
pub fn Stats::add_searches(self : Stats, n : Int64) -> Unit {
  self.searches += n
}

///|
pub fn Stats::add_searches_with_match(self : Stats, n : Int64) -> Unit {
  self.searches_with_match += n
}

///|
pub fn Stats::add_bytes_searched(self : Stats, n : Int64) -> Unit {
  self.bytes_searched += n
}

///|
pub fn Stats::add_bytes_printed(self : Stats, n : Int64) -> Unit {
  self.bytes_printed += n
}

///|
pub fn Stats::add_matched_lines(self : Stats, n : Int64) -> Unit {
  self.matched_lines += n
}

///|
pub fn Stats::add_matches(self : Stats, n : Int64) -> Unit {
  self.matches += n
}

///|
/// Adds all statistics of `rhs` to `self` (Rust's `AddAssign`).
pub fn Stats::add_stats(self : Stats, rhs : Stats) -> Unit {
  self.elapsed += rhs.elapsed
  self.searches += rhs.searches
  self.searches_with_match += rhs.searches_with_match
  self.bytes_searched += rhs.bytes_searched
  self.bytes_printed += rhs.bytes_printed
  self.matched_lines += rhs.matched_lines
  self.matches += rhs.matches
}

///|
/// Returns a new value that is the sum of `self` and `rhs`.
pub impl Add for Stats with fn add(self, rhs) {
  let s = self.clone()
  s.add_stats(rhs)
  s
}

///|
/// Serializes these statistics as JSON, in the same field order as the
/// Rust implementation. When `sorted_keys` is true, the keys are emitted
/// in lexicographic order instead (which matches how `serde_json::json!`
/// serializes a `Stats` value nested in a `Value`, as ripgrep does for its
/// `summary` message).
pub fn Stats::write_json(
  self : Stats,
  w : JsonWriter,
  sorted_keys~ : Bool = false,
) -> Unit {
  let num = (k : String, v : Int64) => {
    w.key(k)
    w.uint64(v.reinterpret_as_uint64())
    w.end_value()
  }
  w.begin_object()
  if sorted_keys {
    num("bytes_printed", self.bytes_printed)
    num("bytes_searched", self.bytes_searched)
    w.key("elapsed")
    write_duration_json(w, self.elapsed, sorted_keys=true)
    w.end_value()
    num("matched_lines", self.matched_lines)
    num("matches", self.matches)
    num("searches", self.searches)
    num("searches_with_match", self.searches_with_match)
  } else {
    w.key("elapsed")
    write_duration_json(w, self.elapsed)
    w.end_value()
    num("searches", self.searches)
    num("searches_with_match", self.searches_with_match)
    num("bytes_searched", self.bytes_searched)
    num("bytes_printed", self.bytes_printed)
    num("matched_lines", self.matched_lines)
    num("matches", self.matches)
  }
  w.end_object()
}

///|
/// Serializes a duration (given in nanoseconds) as
/// `{"secs":..,"nanos":..,"human":"0.000123s"}` exactly like grep-printer's
/// `NiceDuration`. With `sorted_keys`, the keys are emitted in
/// lexicographic order (`human`, `nanos`, `secs`).
pub fn write_duration_json(
  w : JsonWriter,
  nanos : Int64,
  sorted_keys~ : Bool = false,
) -> Unit {
  let secs = nanos / 1_000_000_000L
  let sub = nanos % 1_000_000_000L
  let human = format_duration_human(nanos)
  w.begin_object()
  if sorted_keys {
    w.key("human")
    w.write_escaped_string(human)
    w.end_value()
    w.key("nanos")
    w.uint64(sub.reinterpret_as_uint64())
    w.end_value()
    w.key("secs")
    w.uint64(secs.reinterpret_as_uint64())
    w.end_value()
  } else {
    w.key("secs")
    w.uint64(secs.reinterpret_as_uint64())
    w.end_value()
    w.key("nanos")
    w.uint64(sub.reinterpret_as_uint64())
    w.end_value()
    w.key("human")
    w.write_escaped_string(human)
    w.end_value()
  }
  w.end_object()
}

///|
/// Returns the duration (in nanoseconds) as fractional seconds, computed
/// exactly like Rust's `Duration::as_secs_f64`-style arithmetic used by
/// grep-printer: `secs as f64 + (subsec_nanos as f64) / 1e9`.
pub fn duration_as_secs_f64(nanos : Int64) -> Double {
  let secs = nanos / 1_000_000_000L
  let sub = nanos % 1_000_000_000L
  let fractional = sub.to_double() / 1_000_000_000.0
  secs.to_double() + fractional
}

///|
/// Formats a duration like grep-printer's `NiceDuration` `Display` impl,
/// i.e., `format!("{:0.6}s", fractional_seconds)`.
pub fn format_duration_human(nanos : Int64) -> String {
  format_fixed(duration_as_secs_f64(nanos), 6) + "s"
}

///|
/// Formats a finite, non-negative double with exactly `prec` digits after
/// the decimal point, rounding the exact binary value half-to-even. This
/// matches Rust's `format!("{:.prec$}", x)` for such values.
pub fn format_fixed(x : Double, prec : Int32) -> String {
  let bits = x.reinterpret_as_uint64()
  let neg = bits >> 63 != 0
  let exp = ((bits >> 52) & 0x7FFUL).to_int()
  let frac = bits & ((1UL << 52) - 1UL)
  let (m, e) = if exp == 0 {
    (frac, -1074)
  } else {
    (frac | (1UL << 52), exp - 1075)
  }
  let mut scale = @bigint.BigInt::from_int(1)
  for _ in 0..<prec {
    scale = scale * @bigint.BigInt::from_int(10)
  }
  let bm = @bigint.BigInt::from_uint64(m)
  let q = if e >= 0 {
    (bm << e) * scale
  } else {
    let num = bm * scale
    let k = -e
    let q0 = num >> k
    let r = num - (q0 << k)
    let half = @bigint.BigInt::from_int(1) << (k - 1)
    if r > half ||
      (
        r == half &&
        q0 % @bigint.BigInt::from_int(2) != @bigint.BigInt::from_int(0)
      ) {
      q0 + @bigint.BigInt::from_int(1)
    } else {
      q0
    }
  }
  let mut digits = q.to_string()
  while digits.length() < prec + 1 {
    digits = "0" + digits
  }
  let int_len = digits.length() - prec
  let int_part = digits.view(end_offset=int_len).to_owned()
  let frac_part = digits.view(start_offset=int_len).to_owned()
  let sign = if neg && q != @bigint.BigInt::from_int(0) { "-" } else { "" }
  if prec == 0 {
    sign + int_part
  } else {
    sign + int_part + "." + frac_part
  }
}
