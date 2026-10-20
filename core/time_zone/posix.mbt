///|
priv struct Offset {
  seconds : Int32
  name : String
  dst : Bool
}

///|
priv enum Rule {
  Month(Int32, Int32, Int32, Int32)
  Day(Int32, Bool, Int32)
}

///|
priv struct Rules {
  standard : Offset
  daylight : Offset?
  start : Rule?
  end : Rule?
}

///|
priv struct Cursor {
  source : String
  mut index : Int32
}

///|
fn Cursor::number(self : Cursor) -> Int32 raise {
  let start = self.index
  while self.index < self.source.length() &&
        self.source[self.index] is ('0'..<='9') {
    self.index += 1
  }
  guard self.index > start else { fail("invalid POSIX timezone number") }
  @string.parse_int(self.source[start:self.index].to_owned())
}

///|
fn Cursor::take(self : Cursor, value : UInt16) -> Bool {
  if self.index < self.source.length() && self.source[self.index] == value {
    self.index += 1
    true
  } else {
    false
  }
}

///|
fn Cursor::name(self : Cursor) -> String raise {
  let quoted = self.take('<')
  let start = self.index
  while self.index < self.source.length() &&
        (
          self.source[self.index] is ('A'..<='Z' | 'a'..<='z') ||
          (quoted && self.source[self.index] is ('0'..<='9' | '+' | '-'))
        ) {
    self.index += 1
  }
  let name = self.source[start:self.index].to_owned()
  guard name.length() >= 3 && (!quoted || self.take('>')) else {
    fail("invalid POSIX timezone name")
  }
  name
}

///|
fn Cursor::clock(self : Cursor, maximum_hour : Int32) -> Int32 raise {
  let sign = if self.take('-') {
    -1
  } else {
    ignore(self.take('+'))
    1
  }
  let hours = self.number()
  let minutes = if self.take(':') { self.number() } else { 0 }
  let seconds = if self.take(':') { self.number() } else { 0 }
  guard hours <= maximum_hour && minutes < 60 && seconds < 60 else {
    fail("invalid POSIX timezone offset")
  }
  sign * (hours * 3600 + minutes * 60 + seconds)
}

///|
fn Cursor::rule(self : Cursor) -> Rule raise {
  if self.take('M') {
    let month = self.number()
    guard self.take('.') else { fail("invalid timezone transition") }
    let week = self.number()
    guard self.take('.') else { fail("invalid timezone transition") }
    let weekday = self.number()
    guard month >= 1 && month <= 12 && week >= 1 && week <= 5 && weekday <= 6 else {
      fail("invalid timezone transition")
    }
    let seconds = if self.take('/') { self.clock(167) } else { 7200 }
    Month(month, week, weekday, seconds)
  } else {
    let julian = self.take('J')
    let day = self.number()
    guard (if julian { day >= 1 && day <= 365 } else { day <= 365 }) else {
      fail("invalid timezone transition day")
    }
    let seconds = if self.take('/') { self.clock(167) } else { 7200 }
    Day(day, julian, seconds)
  }
}

///|
fn parse_rules(text : String) -> Rules raise {
  let parser = { source: text, index: 0, }
  let name = parser.name()
  let seconds = -parser.clock(24)
  let standard = { seconds, name, dst: false, }
  if parser.index == text.length() {
    return { standard, daylight: None, start: None, end: None, }
  }
  let name = parser.name()
  let seconds = if parser.index < text.length() && text[parser.index] != ',' {
    -parser.clock(24)
  } else {
    seconds + 3600
  }
  let daylight = Some({ seconds, name, dst: true, })
  guard parser.take(',') else {
    fail("POSIX DST timezone requires explicit transition rules")
  }
  let start = Some(parser.rule())
  guard parser.take(',') else { fail("missing POSIX DST end rule") }
  let end = Some(parser.rule())
  guard parser.index == text.length() else {
    fail("unsupported POSIX timezone suffix")
  }
  { standard, daylight, start, end, }
}

///|
fn transition(rule : Rule, year : Int32, offset : Int32) -> Int64 raise {
  let (day, seconds) = match rule {
    Month(month, week, weekday, seconds) => {
      let first = @time.PlainDate::of(year, month, 1)
      let weekday_first = ((first.to_unix_day() + 4L) % 7L + 7L).to_int() % 7
      let mut n = 1 + (weekday - weekday_first + 7) % 7 + (week - 1) * 7
      let next_month = first.add_months(1L).to_unix_day()
      if first.to_unix_day() + (n - 1).to_int64() >= next_month {
        n -= 7
      }
      (first.to_unix_day() + (n - 1).to_int64(), seconds)
    }
    Day(n, julian, seconds) => {
      let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
      let n = if julian {
        n - 1 + (if leap && n >= 60 { 1 } else { 0 })
      } else {
        n
      }
      (@time.PlainDate::of(year, 1, 1).to_unix_day() + n.to_int64(), seconds)
    }
  }
  day * 86400L + seconds.to_int64() - offset.to_int64()
}

///|
fn Rules::offset(self : Rules, instant : Int64) -> Offset raise {
  guard self.daylight is Some(daylight) &&
    self.start is Some(start) &&
    self.end is Some(end) else {
    return self.standard
  }
  let year = @time.unix(instant).year()
  // Check intervals starting in adjacent years too: southern hemisphere DST
  // spans New Year; signed /time fields may cross a date or year boundary.
  for y in (year - 1)..<=(year + 1) {
    let begin = transition(start, y, self.standard.seconds)
    let mut finish = transition(end, y, daylight.seconds)
    if finish <= begin {
      finish = transition(end, y + 1, daylight.seconds)
    }
    if instant >= begin && instant < finish {
      return daylight
    }
  }
  self.standard
}
