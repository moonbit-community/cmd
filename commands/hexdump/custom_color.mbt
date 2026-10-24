///|
fn color_sequence(name : String) -> String? {
  let code = match name {
    "black" => "30"
    "red" => "31"
    "green" => "32"
    "brown" => "33"
    "blue" => "34"
    "magenta" => "35"
    "cyan" => "36"
    "gray" => "37"
    "darkgray" => "1;30"
    "lightred" => "1;31"
    "lightgreen" => "1;32"
    "yellow" => "1;33"
    "lightblue" => "1;34"
    "lightmagenta" => "1;35"
    "lightcyan" => "1;36"
    "white" => "1;37"
    "reset" => "0"
    "bold" => "1"
    "halfbright" => "2"
    "blink" => "5"
    "reverse" => "7"
    _ => return None
  }
  Some("\u001b[" + code + "m")
}

///|
fn color_offset(
  data : BytesView,
  original : BytesView,
) -> Int64 raise HexdumpError {
  let offset = @string.parse_int64(format_text(data)) catch {
    _ => {
      bad_format(original)
      0L
    }
  }
  if offset < 0 {
    bad_format(original)
  }
  offset
}

///|
fn parse_colors(
  data : BytesView,
  count : Int32,
) -> Array[ColorRule] raise HexdumpError {
  let rules : Array[ColorRule] = []
  let mut start = 0
  while start < data.length() {
    let mut end = start
    while end < data.length() && data[end] != b',' {
      end += 1
    }
    let part = data[start:end]
    let inverted = part.length() > 0 && part[0] == b'!'
    let mut index = if inverted { 1 } else { 0 }
    let name_start = index
    while index < part.length() && !(part[index] is (b':' | b'@')) {
      index += 1
    }
    let sequence = match color_sequence(format_text(part[name_start:index])) {
      Some(sequence) => sequence
      None => return []
    }
    let mut value = AnyValue
    if index < part.length() && part[index] == b':' {
      index += 1
      let value_start = index
      while index < part.length() && part[index] != b'@' {
        index += 1
      }
      let bytes = part[value_start:index]
      if bytes.length() > 0 && bytes[0] == b'0' {
        let hexadecimal = bytes.length() > 1 && bytes[1] is (b'x' | b'X')
        let number = @string.parse_uint64(
          format_text(if hexadecimal { bytes[2:] } else { bytes }),
          base=if hexadecimal { 16 } else { 8 },
        ) catch {
          _ => {
            bad_format(data)
            0UL
          }
        }
        value = if number.to_int() == -1 {
          AnyValue
        } else {
          NumberValue(number.to_int())
        }
      } else {
        value = StringBytes(bytes.to_owned())
      }
    }
    let mut offset : Int64? = None
    let mut span = count
    if index < part.length() && part[index] == b'@' {
      index += 1
      let offset_start = index
      while index < part.length() && part[index] != b'-' {
        index += 1
      }
      let first = color_offset(part[offset_start:index], data)
      offset = Some(first)
      if index < part.length() {
        let last = color_offset(part[index + 1:], data)
        if last < first || last - first >= 2147483647L {
          bad_count("_L")
        }
        span = (last - first + 1).to_int()
        if count == 0 && span > 0 {
          bad_count("_L")
        }
      }
    }
    if value is StringBytes(bytes) {
      let last_span = if count > 0 && span > count {
        (span - 1) % count + 1
      } else {
        span
      }
      if bytes.length() != last_span {
        bad_count("_L")
      }
    }
    rules.push({ sequence, inverted, value, offset, span, })
    start = end + 1
  }
  rules
}

///|
fn colored_sequence(
  atom : PrintAtom,
  data : BytesView,
  position : Int32,
  address : Int64,
) -> String? {
  for rule in atom.colors {
    let mut start = rule.offset.unwrap_or(address)
    let mut span = rule.span
    if atom.count > 0 && span > atom.count {
      let skipped = if address > start {
        (address - start + atom.count.to_int64() - 1) / atom.count.to_int64()
      } else {
        0L
      }
      let consumed = skipped * atom.count.to_int64()
      if consumed >= span.to_int64() {
        continue
      }
      start += consumed
      span = if span.to_int64() - consumed > atom.count.to_int64() {
        atom.count
      } else {
        (span.to_int64() - consumed).to_int()
      }
    }
    if start < address ||
      start - address > atom.count.to_int64() ||
      span.to_int64() > atom.count.to_int64() - (start - address) {
      continue
    }
    let offset = position + (start - address).to_int()
    let matched = match rule.value {
      AnyValue => return Some(rule.sequence)
      NumberValue(value) =>
        if atom.conversion is Some(Address(_, _)) {
          address == value.to_int64()
        } else {
          input_integer(data, offset, span).to_int() == value
        }
      StringBytes(bytes) => {
        let mut matched = true
        for index in 0..<span {
          let expected = bytes.get(index).unwrap_or(b'\x00')
          let actual = data.get(offset + index).unwrap_or(b'\x00')
          if expected != actual {
            matched = false
            break
          }
          if expected == b'\x00' {
            break
          }
        }
        matched
      }
    }
    if matched != rule.inverted {
      return Some(rule.sequence)
    }
  }
  None
}
