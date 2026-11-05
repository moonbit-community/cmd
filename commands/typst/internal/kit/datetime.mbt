// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// Date and time manipulation (upstream `typst_kit::datetime`).
//
// In particular, this module provides the necessary building pieces for
// `World::today`.

///|
/// The current date and time.
pub struct Time {
  priv inner : TimeInner
}

///|
/// The internal representation of a [`Time`].
priv enum TimeInner {
  /// A fixed date and time (a UNIX timestamp in seconds, UTC).
  Fixed(Int64)
  /// The current date and time if the time is not externally fixed (a
  /// memoized UNIX timestamp in milliseconds).
  System(Ref[Int64?])
}

///|
/// Use a fixed timestamp to provide the current date. Used for
/// reproducible builds.
///
/// This timestamp is usually provided using the `SOURCE_DATE_EPOCH`
/// environment variable.
///
/// Returns an error if the timestamp is out of range.
pub fn Time::fixed_timestamp(timestamp : Int64) -> Time raise StrError {
  guard UtcDateTime::from_timestamp(timestamp) is Some(_) else {
    raise StrError("timestamp is out of range")
  }
  { inner: Fixed(timestamp), }
}

///|
/// Rely on the system to provide the current date.
pub fn Time::system() -> Time {
  { inner: System({ val: None, }), }
}

///|
/// The current date.
///
/// A timezone offset can be given to obtain the current date in this
/// timezone.
///
/// This can directly be used to implement `World::today`.
pub fn Time::today(
  self : Time,
  offset : @library.Duration?,
) -> @library.Datetime? {
  // The current time as seconds since the epoch and its UTC offset.
  let (now, now_offset) = match self.inner {
    Fixed(time) => (time, 0)
    System(cell) => {
      let ms = match cell.val {
        Some(ms) => ms
        None => {
          let ms = @platform.now_ms()
          cell.val = Some(ms)
          ms
        }
      }
      let secs = floor_div(ms, 1000L)
      if offset is Some(_) {
        // Actual offset will be applied later.
        (secs, 0)
      } else {
        (secs, @platform.local_offset(secs))
      }
    }
  }

  // The time with the specified UTC offset.
  let with_offset = match offset {
    None => now + now_offset.to_int64()
    Some(offset) => {
      let seconds = offset.seconds().trunc()
      // Check whether we can convert seconds from f64 to i32
      if seconds.is_nan() ||
        seconds.is_inf() ||
        seconds < -2147483648.0 ||
        seconds > 2147483647.0 {
        return None
      }
      // `FixedOffset::east_opt` only accepts offsets below one day.
      let seconds = seconds.to_int64()
      if seconds <= -86400L || seconds >= 86400L {
        return None
      }
      now + seconds
    }
  }
  guard UtcDateTime::from_timestamp(with_offset) is Some(dt) else {
    return None
  }
  @library.Datetime::from_ymd(dt.year, dt.month, dt.day)
}

///|
/// If not a fixed time, resets the memoized time fetched from the system.
///
/// It will be fetched again the next time [`today`](Self::today) is called.
/// This is usually called in between compilations.
pub fn Time::reset(self : Time) -> Unit {
  if self.inner is System(cell) {
    cell.val = None
  }
}

///|
/// A proleptic Gregorian date and time (like `chrono::NaiveDateTime`),
/// computed from a UNIX timestamp.
#derive(Eq, Debug)
pub(all) struct UtcDateTime {
  year : Int32
  month : Int32
  day : Int32
  hour : Int32
  minute : Int32
  second : Int32
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend UtcDateTime with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend UtcDateTime with @debug.Debug::{to_repr}

///|
/// The date and time of a UNIX timestamp (`chrono::DateTime::
/// from_timestamp(secs, 0)`), or `None` if it is out of chrono's range.
pub fn UtcDateTime::from_timestamp(timestamp : Int64) -> UtcDateTime? {
  let days = floor_div(timestamp, 86400L)
  let secs = timestamp - days * 86400L
  // chrono supports the years -262143..=262142.
  if days < -200000000L || days > 200000000L {
    return None
  }
  let (year, month, day) = civil_from_days(days)
  if year < -262143 || year > 262142 {
    return None
  }
  let secs = secs.to_int()
  Some({
    year,
    month,
    day,
    hour: secs / 3600,
    minute: secs % 3600 / 60,
    second: secs % 60,
  })
}

///|
/// The current UTC date and time.
pub fn UtcDateTime::now() -> UtcDateTime {
  UtcDateTime::from_timestamp(floor_div(@platform.now_ms(), 1000L)).unwrap()
}

///|
fn floor_div(a : Int64, b : Int64) -> Int64 {
  let q = a / b
  if a % b != 0L && (a < 0L) != (b < 0L) {
    q - 1L
  } else {
    q
  }
}

///|
/// The proleptic Gregorian date of a day count since 1970-01-01.
fn civil_from_days(days : Int64) -> (Int32, Int32, Int32) {
  let z = days + 719468L
  let era = (if z >= 0L { z } else { z - 146096L }) / 146097L
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let y = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let d = doy - (153L * mp + 2L) / 5L + 1L
  let m = if mp < 10L { mp + 3L } else { mp - 9L }
  let y = if m <= 2L { y + 1L } else { y }
  (y.to_int(), m.to_int(), d.to_int())
}
