///|
fn integer(data : Bytes, at : Int, length : Int) -> Int64 raise {
  guard at >= 0 && length <= data.length() - at else {
    fail("truncated TZif file")
  }
  let mut value = if data[at] >= 128 { -1L } else { 0L }
  for i in at..<(at + length) {
    value = (value << 8) | data[i].to_int64()
  }
  value
}

///|
priv struct Header {
  at : Int
  width : Int
  times : Int
  types : Int
  chars : Int
  end : Int
}

///|
fn header(data : Bytes, at : Int, width : Int) -> Header raise {
  guard at >= 0 && data.length() - at >= 44 && data[at:at + 4] == b"TZif"[:] else {
    fail("invalid TZif header")
  }
  let counts = Array::makei(6, i => integer(data, at + 20 + i * 4, 4).to_int())
  guard counts.all(n => n >= 0 && n <= data.length()) &&
    counts[4] > 0 &&
    counts[4] <= 256 else {
    fail("invalid TZif counts")
  }
  guard counts is [gmt, standard, leaps, times, types, chars] else {
    fail("invalid TZif counts")
  }
  guard leaps == 0 else { fail("leap-second TZif data is unsupported") }
  guard (gmt == 0 || gmt == types) && (standard == 0 || standard == types) else {
    fail("invalid TZif indicators")
  }
  let end = at.to_int64() +
    44L +
    times.to_int64() * (width + 1).to_int64() +
    types.to_int64() * 6L +
    chars.to_int64() +
    (gmt + standard).to_int64()
  guard end <= data.length().to_int64() else { fail("truncated TZif block") }
  { at: at + 44, width, times, types, chars, end: end.to_int(), }
}

///|
/// Decode TZif v1/v2/v3/v4 with bounds checks before every indexed read.
pub fn decode(data : Bytes) -> Zone raise {
  let first = header(data, 0, 4)
  let version = data[4]
  let block = if version == 0 {
    first
  } else {
    guard version is (b'2' | b'3' | b'4') else {
      fail("unsupported TZif version")
    }
    guard first.end + 4 < data.length() && data[first.end + 4] == version else {
      fail("inconsistent TZif version")
    }
    header(data, first.end, 8)
  }
  let indices = block.at + block.times * block.width
  let information = indices + block.times
  let names = information + block.types * 6
  for indicator in data[names + block.chars:block.end] {
    guard indicator <= 1 else { fail("invalid TZif indicator flag") }
  }
  let types : Array[Offset] = []
  for i in 0..<block.types {
    let at = information + i * 6
    let seconds = integer(data, at, 4).to_int()
    guard data[at + 4] <= 1 else { fail("invalid TZif DST flag") }
    let start = names + data[at + 5].to_int()
    guard start < names + block.chars else {
      fail("invalid TZif abbreviation index")
    }
    let mut end = start
    while end < names + block.chars && data[end] != 0 {
      end += 1
    }
    guard end < names + block.chars else {
      fail("unterminated TZif abbreviation")
    }
    let name = @utf8.decode(data[start:end].to_owned())
    types.push({ seconds, name, dst: data[at + 4] != 0, })
  }
  let transitions : Array[(Int64, Int)] = []
  for i in 0..<block.times {
    let instant = integer(data, block.at + i * block.width, block.width)
    let index = data[indices + i].to_int()
    guard index < types.length() && (i == 0 || transitions[i - 1].0 < instant) else {
      fail("invalid TZif transition")
    }
    transitions.push((instant, index))
  }
  let mut future = None
  if version != 0 {
    let footer = @utf8.decode(data[block.end:].to_owned())
    guard footer.has_prefix("\n") &&
      footer.has_suffix("\n") &&
      footer.length() >= 2 else {
      fail("invalid TZif footer")
    }
    let text = footer[1:footer.length() - 1].to_owned()
    if text != "" {
      future = Some(parse_rules(text))
    }
  }
  { types, transitions, future, }
}
