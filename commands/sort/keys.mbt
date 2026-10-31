///|
fn field_ranges(line : Bytes, separator : Byte?) -> Array[(Int32, Int32)] {
  let ranges : Array[(Int32, Int32)] = []
  match separator {
    Some(delimiter) => {
      let mut start = 0
      for index, byte in line {
        if byte == delimiter {
          ranges.push((start, index))
          start = index + 1
        }
      }
      ranges.push((start, line.length()))
    }
    None => {
      let mut start = 0
      let mut index = 0
      let mut seen_nonblank = false
      while index < line.length() {
        if byte_is_blank(line[index]) {
          if seen_nonblank {
            ranges.push((start, index))
            start = index
            seen_nonblank = false
          }
        } else {
          seen_nonblank = true
        }
        index += 1
      }
      if start < line.length() {
        ranges.push((start, line.length()))
      }
    }
  }
  ranges
}

///|
fn key_start(
  line : Bytes,
  position : Position,
  ranges : Array[(Int32, Int32)],
) -> Int32 {
  if position.field > ranges.length() {
    return line.length()
  }
  let (field_start, field_end) = ranges[position.field - 1]
  let mut start = field_start
  if position.skip_blanks {
    while start < field_end && byte_is_blank(line[start]) {
      start += 1
    }
  }
  Int32::min(field_end, start + Int32::max(0, position.character - 1))
}

///|
fn key_end(
  line : Bytes,
  position : Position,
  ranges : Array[(Int32, Int32)],
) -> Int32 {
  if position.field > ranges.length() {
    return line.length()
  }
  let (field_start, field_end) = ranges[position.field - 1]
  let mut start = field_start
  if position.skip_blanks {
    while start < field_end && byte_is_blank(line[start]) {
      start += 1
    }
  }
  if position.character == 0 {
    field_end
  } else {
    Int32::min(field_end, start + position.character)
  }
}

///|
fn extract_key(line : Bytes, spec : KeySpec, separator : Byte?) -> Bytes {
  let ranges = field_ranges(line, separator)
  let start = key_start(line, spec.start, ranges)
  let end = match spec.end {
    Some(position) => key_end(line, position, ranges)
    None => line.length()
  }
  if end <= start {
    b""
  } else {
    line[start:end].to_owned()
  }
}

///|
fn transforms_key(modifiers : Modifiers) -> Bool {
  modifiers.ignore_leading_blanks ||
  modifiers.ignore_nonprinting ||
  modifiers.dictionary_order ||
  modifiers.fold_case
}

///|
fn transformed_key(key : Bytes, modifiers : Modifiers) -> Bytes {
  if !transforms_key(modifiers) {
    return key
  }
  let output : Array[Byte] = []
  let mut start = 0
  if modifiers.ignore_leading_blanks {
    while start < key.length() && byte_is_blank(key[start]) {
      start += 1
    }
  }
  for byte in key[start:] {
    if modifiers.ignore_nonprinting &&
      (byte.to_int() < 0x20 || byte.to_int() > 0x7E) {
      continue
    }
    if modifiers.dictionary_order &&
      !byte_is_blank(byte) &&
      !byte_is_alphanumeric(byte) {
      continue
    }
    let value = byte.to_int()
    output.push(
      if modifiers.fold_case && value >= 0x61 && value <= 0x7A {
        (value - 0x20).to_byte()
      } else {
        byte
      },
    )
  }
  Bytes::from_array(output)
}
