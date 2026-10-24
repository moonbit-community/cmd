///|
fn format_number(
  data : BytesView,
  start : Int32,
) -> (Int32, Int32) raise HexdumpError {
  let mut end = start
  while end < data.length() && data[end] >= b'0' && data[end] <= b'9' {
    end += 1
  }
  let number = @string.parse_int(format_text(data[start:end])) catch {
    _ => {
      bad_format(data)
      0
    }
  }
  (number, end)
}

///|
fn format_escapes(data : BytesView) -> Bytes {
  let output = @buffer.Buffer()
  let mut index = 0
  while index < data.length() {
    let mut byte = data[index]
    if byte == b'\\' && index + 1 < data.length() {
      index += 1
      byte = match data[index] {
        b'a' => b'\x07'
        b'b' => b'\b'
        b'f' => b'\x0c'
        b'n' => b'\n'
        b'r' => b'\r'
        b't' => b'\t'
        b'v' => b'\x0b'
        byte => byte
      }
    }
    output.write_byte(byte)
    index += 1
  }
  output.to_bytes()
}

///|
fn parse_atoms(
  body : Bytes,
  byte_count : Int32?,
  color : Bool,
) -> Array[PrintAtom] raise HexdumpError {
  let atoms : Array[PrintAtom] = []
  let mut start = 0
  let mut index = 0
  let mut conversions = 0
  while index < body.length() {
    if body[index] != b'%' {
      index += 1
      continue
    }
    let prefix = body[start:index].to_owned()
    index += 1
    let mut minus = false
    let mut plus = false
    let mut blank = false
    let mut zero = false
    let mut alternate = false
    while index < body.length() {
      match body[index] {
        b'-' => minus = true
        b'+' => plus = true
        b' ' => blank = true
        b'0' => zero = true
        b'#' => alternate = true
        _ => break
      }
      index += 1
    }
    let mut width = 0
    if index < body.length() && body[index] >= b'0' && body[index] <= b'9' {
      let (value, end) = format_number(body[:], index)
      width = value
      index = end
    }
    let mut precision : Int32? = None
    if index < body.length() && body[index] == b'.' {
      index += 1
      if index < body.length() && body[index] >= b'0' && body[index] <= b'9' {
        let (value, end) = format_number(body[:], index)
        precision = Some(value)
        index = end
      }
    }
    if index == body.length() {
      bad_format(body[:])
    }
    let byte = body[index]
    index += 1
    let mut name = byte.to_int().unsafe_to_char().to_string()
    let conversion = match byte {
      b'd' | b'i' | b'o' | b'u' | b'x' | b'X' =>
        Integer(byte.to_int().unsafe_to_char())
      b'e' | b'E' | b'f' | b'g' | b'G' =>
        Floating(byte.to_int().unsafe_to_char())
      b'c' => Character
      b's' => StringValue
      b'_' => {
        if index == body.length() {
          bad_conversion("_")
        }
        let kind = body[index]
        index += 1
        name += kind.to_int().unsafe_to_char().to_string()
        match kind {
          b'c' => EscapedCharacter
          b'p' => PrintableCharacter
          b'u' => AsciiName
          b'a' | b'A' => {
            if index == body.length() {
              bad_conversion(name)
            }
            let radix = body[index]
            index += 1
            name += radix.to_int().unsafe_to_char().to_string()
            if !(radix is (b'd' | b'o' | b'x')) {
              bad_conversion(name)
            }
            Address(radix.to_int().unsafe_to_char(), kind == b'A')
          }
          _ => {
            bad_conversion(name)
            Character
          }
        }
      }
      _ => {
        bad_conversion(name)
        Character
      }
    }
    let count = match conversion {
      Address(_, _) => 0
      Integer(_) => {
        let count = byte_count.unwrap_or(4)
        if ![1, 2, 4, 8].contains(count) {
          bad_count(name)
        }
        count
      }
      Floating(_) => {
        let count = byte_count.unwrap_or(8)
        if count != 4 && count != 8 {
          bad_count(name)
        }
        count
      }
      StringValue => {
        let length = match byte_count {
          Some(count) => Some(count)
          None => precision
        }
        match length {
          Some(count) => count
          None => raise HexdumpError("%s requires a precision or a byte count")
        }
      }
      _ => {
        if byte_count is Some(count) && count != 1 {
          bad_count(name)
        }
        1
      }
    }
    if count > 0 {
      conversions += 1
      if byte_count is Some(_) && conversions > 1 {
        raise HexdumpError("byte count with multiple conversion characters")
      }
    }
    let mut colors : Array[ColorRule] = []
    if index + 1 < body.length() &&
      body[index] == b'_' &&
      body[index + 1] == b'L' {
      let mut closing : Int32? = None
      for at in (index + 2)..<body.length() {
        if body[at] == b']' {
          closing = Some(at)
        }
      }
      if closing is None {
        bad_conversion("_L")
      }
      let end = closing.unwrap()
      if color {
        let mut opening = index + 2
        while opening < end && body[opening] != b'[' {
          opening += 1
        }
        if opening == end {
          bad_conversion("_L")
        }
        colors = parse_colors(body[opening + 1:end], count)
      }
      index = end + 1
    }
    atoms.push({
      prefix,
      conversion: Some(conversion),
      width,
      precision,
      minus,
      plus,
      blank,
      zero,
      alternate,
      count,
      colors,
    })
    start = index
  }
  if start < body.length() {
    atoms.push({
      prefix: body[start:].to_owned(),
      conversion: None,
      width: 0,
      precision: None,
      minus: false,
      plus: false,
      blank: false,
      zero: false,
      alternate: false,
      count: 0,
      colors: [],
    })
  }
  atoms
}

///|
fn compile_format(
  source : BytesView,
  color : Bool,
) -> CustomFormat raise HexdumpError {
  let units : Array[FormatUnit] = []
  let mut index = 0
  let mut consumption = 0
  while index < source.length() {
    while index < source.length() && format_space(source[index]) {
      index += 1
    }
    if index == source.length() {
      break
    }
    let mut reps = 1
    let mut explicit_reps = false
    if source[index] >= b'0' && source[index] <= b'9' {
      let (value, end) = format_number(source, index)
      if end == source.length() ||
        (!format_space(source[end]) && source[end] != b'/') {
        bad_format(source)
      }
      reps = value
      explicit_reps = true
      index = end + 1
      while index < source.length() && format_space(source[index]) {
        index += 1
      }
    }
    if index < source.length() && source[index] == b'/' {
      index += 1
    }
    while index < source.length() && format_space(source[index]) {
      index += 1
    }
    let mut byte_count : Int32? = None
    if index < source.length() && source[index] >= b'0' && source[index] <= b'9' {
      let (value, end) = format_number(source, index)
      if end == source.length() || !format_space(source[end]) {
        bad_format(source)
      }
      byte_count = if value == 0 { None } else { Some(value) }
      index = end + 1
      while index < source.length() && format_space(source[index]) {
        index += 1
      }
    }
    if index == source.length() || source[index] != b'"' {
      bad_format(source)
    }
    index += 1
    let start = index
    while index < source.length() && source[index] != b'"' {
      index += 1
    }
    if index == source.length() {
      bad_format(source)
    }
    let body = format_escapes(source[start:index])
    index += 1
    let atoms = parse_atoms(body, byte_count, color)
    let mut count = 0
    let mut final_address = false
    for atom in atoms {
      if atom.count > 2147483647 - count {
        bad_format(source)
      }
      count += atom.count
      if atom.conversion is Some(Address(_, true)) {
        final_address = true
      }
    }
    let count = byte_count.unwrap_or(count)
    if reps > 0 && count > (2147483647 - consumption) / reps {
      bad_format(source)
    }
    consumption += reps * count
    units.push({
      atoms,
      reps,
      explicit_reps,
      count,
      final_address,
      trim_tail: body.length() > 0 && format_space(body[body.length() - 1]),
    })
  }
  { units, count: consumption, }
}
