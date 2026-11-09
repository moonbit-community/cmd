///|
#derive(Eq)
priv enum WgetDateLayout {
  Rfc1123
  Rfc850
  Asctime
  Netscape
}

///|
priv struct WgetDate {
  text : String
  mut offset : Int32
}

///|
let wget_date_weekdays : ReadOnlyArray[String] = [
  "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
]

///|
let wget_date_months : ReadOnlyArray[String] = [
  "january", "february", "march", "april", "may", "june", "july", "august", "september",
  "october", "november", "december",
]

///|
fn WgetDate::space(self : WgetDate) -> Unit {
  while self.offset < self.text.length() &&
        wget_cookie_space(self.text[self.offset]) {
    self.offset += 1
  }
}

///|
fn WgetDate::take(self : WgetDate, code : UInt16) -> Bool {
  if self.offset < self.text.length() && self.text[self.offset] == code {
    self.offset += 1
    true
  } else {
    false
  }
}

///|
fn WgetDate::number(
  self : WgetDate,
  minimum : Int32,
  maximum : Int32,
  digits : Int32,
) -> Int32? {
  self.space()
  let mut value = 0
  let mut consumed = 0
  while consumed < digits && self.offset < self.text.length() {
    let code = self.text[self.offset]
    if code < 48 || code > 57 || (consumed > 0 && value * 10 > maximum) {
      break
    }
    value = value * 10 + code.to_int() - 48
    consumed += 1
    self.offset += 1
  }
  if consumed > 0 && value >= minimum && value <= maximum {
    Some(value)
  } else {
    None
  }
}

///|
fn WgetDate::named(self : WgetDate, names : ReadOnlyArray[String]) -> Int32? {
  for index, name in names {
    let remaining = self.text[self.offset:]
    let length = if remaining.has_prefix(name) {
      name.length()
    } else if remaining.has_prefix(name[:3]) {
      3
    } else {
      continue
    }
    self.offset += length
    return Some(index)
  }
  None
}

///|
fn WgetDate::clock(self : WgetDate) -> (Int32, Int32, Int32)? {
  guard self.number(0, 23, 2) is Some(hour) &&
    self.take(58) &&
    self.number(0, 59, 2) is Some(minute) &&
    self.take(58) &&
    self.number(0, 61, 2) is Some(second) else {
    return None
  }
  Some((hour, minute, second))
}

///|
fn WgetDate::separator(self : WgetDate, layout : WgetDateLayout) -> Bool {
  if layout == Rfc1123 {
    self.space()
    true
  } else {
    self.take(45)
  }
}

///|
fn WgetDate::fields(
  self : WgetDate,
  layout : WgetDateLayout,
) -> (Int32, Int32, Int32, Int32, Int32, Int32)? {
  if layout == Asctime {
    self.space()
    guard self.named(wget_date_months) is Some(month) else { return None }
    self.space()
    guard self.number(1, 31, 2) is Some(day) else { return None }
    self.space()
    guard self.clock() is Some((hour, minute, second)) else { return None }
    self.space()
    guard self.number(0, 9999, 4) is Some(year) else { return None }
    Some((year, month + 1, day, hour, minute, second))
  } else {
    guard self.take(44) else { return None }
    self.space()
    guard self.number(1, 31, 2) is Some(day) &&
      self.separator(layout) &&
      self.named(wget_date_months) is Some(month) &&
      self.separator(layout) else {
      return None
    }
    let short = layout == Rfc850
    guard self.number(
        0,
        if short {
          99
        } else {
          9999
        },
        if short {
          2
        } else {
          4
        },
      )
      is Some(year) else {
      return None
    }
    let year = if short {
      year + (if year >= 69 { 1900 } else { 2000 })
    } else {
      year
    }
    self.space()
    guard self.clock() is Some((hour, minute, second)) else { return None }
    Some((year, month + 1, day, hour, minute, second))
  }
}

///|
fn wget_cookie_date(text : String) -> Int64? {
  let cursor : WgetDate = { text: cookie_ascii_lower(text), offset: 0, }
  guard cursor.named(wget_date_weekdays) is Some(_) else { return None }
  let after_weekday = cursor.offset
  for layout in [Rfc1123, Rfc850, Asctime, Netscape] {
    cursor.offset = after_weekday
    guard cursor.fields(layout)
      is Some((year, month, day, hour, minute, second)) else {
      continue
    }
    cursor.space()
    // Names compare in the C locale, but Wget's trailing GMT check is
    // case-sensitive and accepts a prefix rather than the entire remaining text.
    let end = text[cursor.offset:]
    if !end.is_empty() &&
      !end.has_prefix("GMT") &&
      !(end.length() >= 2 &&
      (end[0] == 43 || end[0] == 45) &&
      end[1] >= 48 &&
      end[1] <= 57) {
      continue
    }
    // Starting at the month's first day preserves timegm normalization of
    // days 29..31 and seconds 60/61 without requiring an invalid calendar date.
    let first = @time.PlainDate::of(year, month, 1) catch { _ => return None }
    let expiry = (first.to_unix_day() + day.to_int64() - 1L) * 86400L +
      hour.to_int64() * 3600L +
      minute.to_int64() * 60L +
      second.to_int64()
    return if expiry == -1L { None } else { Some(expiry) }
  }
  None
}
