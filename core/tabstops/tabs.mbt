///|
pub(all) suberror TabError {
  TabError(String)
}

///|
struct TabStops {
  columns : Array[Int64]
  interval : Int64
  relative : Bool
}

///|
pub fn parse(values : Array[String]) -> TabStops raise TabError {
  let columns : Array[Int64] = []
  let mut absolute_interval = 0L
  let mut increment = 0L
  for text in values {
    let mut offset = 0
    let mut mode = 0
    while offset < text.length() {
      if text[offset] is (',' | ' ' | '\t') {
        offset += 1
        continue
      }
      if text[offset] is ('/' | '+') {
        mode = if text[offset] == '/' { 1 } else { 2 }
        offset += 1
        continue
      }
      let start = offset
      while offset < text.length() && text[offset] >= '0' && text[offset] <= '9' {
        offset += 1
      }
      if offset == start {
        raise TabError(
          "tab size contains invalid character(s): '\{text[offset:]}'",
        )
      }
      let number = text[start:offset]
      let value = @string.parse_int64(number) catch {
        _ => raise TabError("tab stop is too large '\{number}'")
      }
      if offset < text.length() && !(text[offset] is (',' | ' ' | '\t')) {
        if text[offset] is ('/' | '+') {
          raise TabError(
            "'\{text[offset:offset + 1]}' specifier not at start of number: '\{text[offset:]}'",
          )
        }
        raise TabError(
          "tab size contains invalid character(s): '\{text[offset:]}'",
        )
      }
      match mode {
        1 => {
          if absolute_interval != 0 {
            raise TabError("'/' specifier only allowed with the last value")
          }
          absolute_interval = value
        }
        2 => {
          if increment != 0 {
            raise TabError("'+' specifier only allowed with the last value")
          }
          increment = value
        }
        _ => columns.push(value)
      }
    }
  }
  let mut previous = 0L
  for stop in columns {
    if stop == 0 {
      raise TabError("tab size cannot be 0")
    }
    if stop <= previous {
      raise TabError("tab sizes must be ascending")
    }
    previous = stop
  }
  if absolute_interval != 0 && increment != 0 {
    raise TabError("'/' specifier is mutually exclusive with '+'")
  }
  let interval = if absolute_interval != 0 {
    absolute_interval
  } else {
    increment
  }
  if columns.is_empty() {
    {
      columns,
      interval: if interval == 0 {
        8L
      } else {
        interval
      },
      relative: false,
    }
  } else if columns.length() == 1 && interval == 0 {
    { columns: [], interval: columns[0], relative: false, }
  } else {
    { columns, interval, relative: increment != 0, }
  }
}

///|
pub fn next(column : Int64, stops : TabStops) -> Int64? raise TabError {
  for stop in stops.columns {
    if stop > column {
      return Some(stop)
    }
  }
  if stops.interval == 0 {
    if column == 9223372036854775807L {
      raise TabError("input line is too long")
    }
    return None
  }
  let origin = if stops.relative {
    stops.columns.last().unwrap_or(0L)
  } else {
    0L
  }
  let distance = stops.interval - (column - origin) % stops.interval
  if column > 9223372036854775807L - distance {
    raise TabError("input line is too long")
  }
  Some(column + distance)
}
