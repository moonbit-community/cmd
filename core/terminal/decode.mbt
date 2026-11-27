///|
/// ncurses offsets extended names from the end of the capability values.
/// terminfo 0.1.0 expects offsets from the start of the combined string table.
fn decode(data : Bytes) -> @terminfo.Entry raise {
  guard data.length() >= 12 else {
    raise Failure::Failure("truncated terminal entry")
  }
  let word = fn(pos : Int32) {
    data[pos].to_int() | (data[pos + 1].to_int() << 8)
  }
  let align = fn(n : Int32) { (n + 1) & -2 }
  let width = if word(0) == 0x021e { 4 } else { 2 }
  let ext = align(
    align(12 + word(2) + word(4)) + width * word(6) + 2 * word(8) + word(10),
  )
  if ext + 10 > data.length() {
    return @terminfo.parse(data)
  }
  let bools = word(ext)
  let nums = word(ext + 2)
  let strs = word(ext + 4)
  let table_size = word(ext + 8)
  let offsets = align(ext + 10 + bools) + nums * width
  let names = offsets + 2 * strs
  let name_count = bools + nums + strs
  let table = names + 2 * name_count
  guard table + table_size <= data.length() else {
    raise Failure::Failure("truncated extended terminal data")
  }
  let mut end = 0
  for i = 0; i < strs; i = i + 1 {
    let value = word(offsets + 2 * i)
    if value >= 0xfffe {
      continue
    }
    guard value < table_size else {
      raise Failure::Failure("invalid extended capability offset")
    }
    let mut pos = table + value
    while pos < table + table_size && data[pos] != 0 {
      pos += 1
    }
    guard pos < table + table_size else {
      raise Failure::Failure("unterminated extended capability")
    }
    end = end.max(pos - table + 1)
  }
  let fixed = data.to_fixedarray()
  for i = 0; i < name_count; i = i + 1 {
    let pos = names + 2 * i
    let absolute = end + word(pos)
    guard absolute < table_size && absolute <= 32767 else {
      raise Failure::Failure("invalid extended capability name offset")
    }
    fixed[pos] = absolute.to_byte()
    fixed[pos + 1] = (absolute >> 8).to_byte()
  }
  @terminfo.parse(Bytes::from_array(fixed[:]))
}
