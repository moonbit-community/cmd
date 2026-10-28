///|
fn numeric_slice(key : Bytes, exponent : Bool, allow_plus : Bool) -> Bytes? {
  let mut index = 0
  while index < key.length() && byte_is_blank(key[index]) {
    index += 1
  }
  let start = index
  if index < key.length() && key[index] is b'-' {
    index += 1
  } else if allow_plus && index < key.length() && key[index] is b'+' {
    index += 1
  }
  let mut digits = 0
  while index < key.length() && byte_is_digit(key[index]) {
    digits += 1
    index += 1
  }
  if index < key.length() && key[index] is b'.' {
    index += 1
    while index < key.length() && byte_is_digit(key[index]) {
      digits += 1
      index += 1
    }
  }
  if exponent &&
    digits > 0 &&
    index < key.length() &&
    (key[index] is b'e' || key[index] is b'E') {
    let exponent_start = index
    index += 1
    if index < key.length() && (key[index] is b'+' || key[index] is b'-') {
      index += 1
    }
    let exponent_digits = index
    while index < key.length() && byte_is_digit(key[index]) {
      index += 1
    }
    if exponent_digits == index {
      index = exponent_start
    }
  }
  if digits == 0 {
    return None
  }
  Some(key[start:index].to_owned())
}

///|
fn numeric_prefix(key : Bytes, exponent : Bool) -> Double {
  match numeric_slice(key, exponent, exponent) {
    Some(number) =>
      @string.parse_double(@utf8.decode(number)) catch {
        _ => 0.0
      }
    None => 0.0
  }
}

///|
fn ascii_lower_byte(byte : Byte) -> Byte {
  let value = byte.to_int()
  if value >= 0x41 && value <= 0x5A {
    (value + 0x20).to_byte()
  } else {
    byte
  }
}

///|
fn ascii_prefix_at(key : Bytes, index : Int32, prefix : Bytes) -> Bool {
  if index + prefix.length() > key.length() {
    return false
  }
  for offset, byte in prefix {
    if ascii_lower_byte(key[index + offset]) != byte {
      return false
    }
  }
  true
}

///|
fn general_number(key : Bytes) -> GeneralNumber {
  let mut index = 0
  while index < key.length() && byte_is_blank(key[index]) {
    index += 1
  }
  let mut negative = false
  if index < key.length() && key[index] is b'-' {
    negative = true
    index += 1
  } else if index < key.length() && key[index] is b'+' {
    index += 1
  }
  if ascii_prefix_at(key, index, b"nan") {
    return NotANumber
  }
  if ascii_prefix_at(key, index, b"inf") {
    return if negative { NegativeInfinity } else { PositiveInfinity }
  }
  match numeric_slice(key, true, true) {
    None => NonNumber
    Some(number) => {
      let value = @string.parse_double(@utf8.decode(number)) catch {
        _ => return NonNumber
      }
      if value.is_nan() {
        NotANumber
      } else if value.is_inf() {
        if value < 0.0 {
          NegativeInfinity
        } else {
          PositiveInfinity
        }
      } else {
        Finite(value)
      }
    }
  }
}

///|
fn general_compare(left : Bytes, right : Bytes) -> Int32 {
  match (general_number(left), general_number(right)) {
    (NonNumber, NonNumber) | (NotANumber, NotANumber) => 0
    (NonNumber, _) => -1
    (_, NonNumber) => 1
    (NotANumber, _) => -1
    (_, NotANumber) => 1
    (NegativeInfinity, NegativeInfinity) => 0
    (NegativeInfinity, _) => -1
    (_, NegativeInfinity) => 1
    (PositiveInfinity, PositiveInfinity) => 0
    (PositiveInfinity, _) => 1
    (_, PositiveInfinity) => -1
    (Finite(left), Finite(right)) => left.compare(right)
  }
}

///|
fn human_parts(key : Bytes) -> (Int32, Int32, Double) {
  let mut index = 0
  while index < key.length() && byte_is_blank(key[index]) {
    index += 1
  }
  let start = index
  if index < key.length() && key[index] is b'-' {
    index += 1
  } else if index < key.length() && key[index] is b'+' {
    return (0, 0, 0.0)
  }
  let mut digits = 0
  while index < key.length() && byte_is_digit(key[index]) {
    digits += 1
    index += 1
  }
  if index < key.length() && key[index] is b'.' {
    index += 1
    while index < key.length() && byte_is_digit(key[index]) {
      digits += 1
      index += 1
    }
  }
  if digits == 0 {
    return (0, 0, 0.0)
  }
  let number = @string.parse_double(@utf8.decode(key[start:index].to_owned())) catch {
    _ => 0.0
  }
  let power = if index < key.length() {
    match key[index] {
      b'K' | b'k' => 1
      b'M' => 2
      b'G' => 3
      b'T' => 4
      b'P' => 5
      b'E' => 6
      b'Z' => 7
      b'Y' => 8
      b'R' => 9
      b'Q' => 10
      _ => 0
    }
  } else {
    0
  }
  let sign = if number < 0.0 { -1 } else if number > 0.0 { 1 } else { 0 }
  (sign, power, number)
}

///|
fn human_compare(left : Bytes, right : Bytes) -> Int32 {
  let (left_sign, left_power, left_value) = human_parts(left)
  let (right_sign, right_power, right_value) = human_parts(right)
  if left_sign != right_sign {
    return left_sign - right_sign
  }
  if left_power != right_power {
    return if left_sign < 0 {
      right_power - left_power
    } else {
      left_power - right_power
    }
  }
  left_value.compare(right_value)
}

///|
fn month_value(key : Bytes) -> Int32 {
  let text = transformed_key(key, {
    ignore_leading_blanks: true,
    dictionary_order: false,
    fold_case: true,
    ignore_nonprinting: false,
    mode: Lexical,
    ordering_modes: 0,
    reverse: false,
  })
  let text = @utf8.decode(text) catch { _ => "" }
  if text.length() < 3 {
    return 0
  }
  match text[0:3].to_owned() {
    "JAN" => 1
    "FEB" => 2
    "MAR" => 3
    "APR" => 4
    "MAY" => 5
    "JUN" => 6
    "JUL" => 7
    "AUG" => 8
    "SEP" => 9
    "OCT" => 10
    "NOV" => 11
    "DEC" => 12
    _ => 0
  }
}

///|
fn version_compare(left : Bytes, right : Bytes) -> Int32 {
  let mut li = 0
  let mut ri = 0
  while li < left.length() || ri < right.length() {
    if li < left.length() && left[li] is b'~' {
      if ri < right.length() && right[ri] is b'~' {
        li += 1
        ri += 1
        continue
      }
      return -1
    }
    if ri < right.length() && right[ri] is b'~' {
      return 1
    }
    if li == left.length() {
      return -1
    }
    if ri == right.length() {
      return 1
    }
    if byte_is_digit(left[li]) && byte_is_digit(right[ri]) {
      let mut lzero = li
      while lzero < left.length() && left[lzero] is b'0' {
        lzero += 1
      }
      let mut rzero = ri
      while rzero < right.length() && right[rzero] is b'0' {
        rzero += 1
      }
      let mut lend = lzero
      while lend < left.length() && byte_is_digit(left[lend]) {
        lend += 1
      }
      let mut rend = rzero
      while rend < right.length() && byte_is_digit(right[rend]) {
        rend += 1
      }
      let llen = lend - lzero
      let rlen = rend - rzero
      if llen != rlen {
        return llen - rlen
      }
      let cmp = left[lzero:lend].lexical_compare(right[rzero:rend])
      if cmp != 0 {
        return cmp
      }
      li = lend
      ri = rend
    } else {
      if left[li] != right[ri] {
        return left[li].to_int() - right[ri].to_int()
      }
      li += 1
      ri += 1
    }
  }
  0
}

///|
fn compare_prepared_key(
  left : Bytes,
  right : Bytes,
  modifiers : Modifiers,
) -> Int32 {
  let result = match modifiers.mode {
    Lexical => left.lexical_compare(right)
    Numeric => numeric_prefix(left, false).compare(numeric_prefix(right, false))
    GeneralNumeric => general_compare(left, right)
    HumanNumeric => human_compare(left, right)
    Month => month_value(left) - month_value(right)
    Version => version_compare(left, right)
    Random => left.lexical_compare(right)
  }
  if modifiers.reverse {
    -result
  } else {
    result
  }
}

///|
fn compare_entries(
  left : Entry,
  right : Entry,
  specs : Array[KeySpec],
  global : Modifiers,
  last_resort : Bool,
) -> Int32 {
  if specs.is_empty() {
    let result = compare_prepared_key(
      left.keys.get(0).unwrap_or(left.record),
      right.keys.get(0).unwrap_or(right.record),
      global,
    )
    if result != 0 || !last_resort {
      return result
    }
  } else {
    for index, spec in specs {
      let result = compare_prepared_key(
        left.keys[index],
        right.keys[index],
        spec.modifiers,
      )
      if result != 0 {
        return result
      }
    }
    if !last_resort {
      return 0
    }
  }
  let result = left.record.lexical_compare(right.record)
  if global.reverse {
    -result
  } else {
    result
  }
}

///|
fn make_entry(
  record : Bytes,
  index : Int64,
  specs : Array[KeySpec],
  global : Modifiers,
  separator : Byte?,
  seed~ : Bytes = b"",
) -> Entry {
  let keys = if specs.is_empty() {
    if transforms_key(global) || global.mode == Random {
      [prepared_key(record, global, seed)]
    } else {
      []
    }
  } else {
    specs.map(spec => {
      prepared_key(extract_key(record, spec, separator), spec.modifiers, seed)
    })
  }
  { record, keys, index, }
}
