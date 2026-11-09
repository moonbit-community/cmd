///|
fn wget_cookie_digit(code : UInt16) -> Int32 {
  if code >= 48 && code <= 57 {
    code.to_int() - 48
  } else if code >= 65 && code <= 70 {
    code.to_int() - 55
  } else if code >= 97 && code <= 102 {
    code.to_int() - 87
  } else {
    -1
  }
}

///|
// The pinned Wget uses the C-locale scanf floating prefix, not a complete
// decimal integer. Keep that grammar local to its Cookie expiry fields.
fn wget_cookie_number(text : String) -> Double? {
  let mut start = 0
  while start < text.length() && wget_cookie_space(text[start]) {
    start += 1
  }
  let mut offset = start
  let negative = offset < text.length() && text[offset] == 45
  if offset < text.length() && (text[offset] == 43 || text[offset] == 45) {
    offset += 1
  }
  let rest = cookie_ascii_lower(
    text[offset:offset + (text.length() - offset).min(8)].to_owned(),
  )
  if rest.has_prefix("nan") {
    return Some(0x7ff8000000000000UL.reinterpret_as_double())
  }
  if rest.has_prefix("inf") {
    // scanf consumes the whole infinity spelling once the fourth letter starts.
    if rest.has_prefix("infi") && !rest.has_prefix("infinity") {
      return None
    }
    let infinity = 0x7ff0000000000000UL.reinterpret_as_double()
    return Some(if negative { -infinity } else { infinity })
  }
  if rest.has_prefix("0x") {
    return wget_cookie_hex(text, offset + 2, negative)
  }
  let mut digits = 0
  while offset < text.length() && text[offset] >= 48 && text[offset] <= 57 {
    digits += 1
    offset += 1
  }
  if offset < text.length() && text[offset] == 46 {
    offset += 1
    while offset < text.length() && text[offset] >= 48 && text[offset] <= 57 {
      digits += 1
      offset += 1
    }
  }
  guard digits > 0 else { return None }
  let significand_end = offset
  if offset < text.length() && (text[offset] == 69 || text[offset] == 101) {
    offset += 1
    if offset < text.length() && (text[offset] == 43 || text[offset] == 45) {
      offset += 1
    }
    let exponent_start = offset
    while offset < text.length() && text[offset] >= 48 && text[offset] <= 57 {
      offset += 1
    }
    if offset == exponent_start {
      offset = significand_end
    }
  }
  Some(@string.parse_double(text[start:offset])) catch {
    // The prefix above is syntactically valid; the public converter reports
    // finite decimal overflow as an error, whereas scanf returns infinity.
    _ => {
      let infinity = 0x7ff0000000000000UL.reinterpret_as_double()
      Some(if negative { -infinity } else { infinity })
    }
  }
}

///|
fn wget_cookie_hex(text : String, start : Int32, negative : Bool) -> Double? {
  let mut offset = start
  let mut digits = 0L
  let mut before_point = 0L
  let mut point = false
  let mut first_digit = -1L
  let mut first_bit = 0
  while offset < text.length() {
    if text[offset] == 46 && !point {
      point = true
      before_point = digits
      offset += 1
      continue
    }
    let digit = wget_cookie_digit(text[offset])
    if digit < 0 {
      break
    }
    if first_digit < 0L && digit != 0 {
      first_digit = digits
      first_bit = if digit >= 8 {
        3
      } else if digit >= 4 {
        2
      } else if digit >= 2 {
        1
      } else {
        0
      }
    }
    digits += 1L
    offset += 1
  }
  // The fixed scanf profile accepts a hexadecimal point without digits as
  // zero, even with an incomplete exponent or suffix. Bare "0x" still fails.
  guard digits > 0L || point else { return None }
  if !point {
    before_point = digits
  }
  let significand_end = offset
  let mut exponent = 0L
  if offset < text.length() && (text[offset] == 80 || text[offset] == 112) {
    offset += 1
    let exponent_negative = offset < text.length() && text[offset] == 45
    if offset < text.length() && (text[offset] == 43 || text[offset] == 45) {
      offset += 1
    }
    while offset < text.length() && text[offset] >= 48 && text[offset] <= 57 {
      // String lengths are Int32; this bound exceeds every possible digit shift.
      exponent = (exponent * 10L + (text[offset].to_int() - 48).to_int64()).min(
        100000000000L,
      )
      offset += 1
    }
    if exponent_negative {
      exponent = -exponent
    }
  }
  if first_digit < 0L {
    return Some(if negative { -0.0 } else { 0.0 })
  }
  exponent += (before_point - first_digit - 1L) * 4L + first_bit.to_int64()
  if exponent > 1023L {
    let infinity = 0x7ff0000000000000UL.reinterpret_as_double()
    return Some(if negative { -infinity } else { infinity })
  }
  if exponent < -1075L {
    return Some(if negative { -0.0 } else { 0.0 })
  }
  // Retain the binary64 significand and round once, including subnormal ties.
  // Reading every remaining bit supplies the sticky bit without a big integer.
  let keep = (exponent + 1075L).min(53L).to_int()
  let mut mantissa = 0UL
  let mut seen = false
  let mut count = 0
  let mut guard_bit = false
  let mut sticky = false
  for index = start; index < significand_end; index = index + 1 {
    let digit = wget_cookie_digit(text[index])
    if digit < 0 {
      continue
    }
    for bit = 3; bit >= 0; bit = bit - 1 {
      let set = (digit & (1 << bit)) != 0
      if !seen && !set {
        continue
      }
      seen = true
      if count < keep {
        mantissa = (mantissa << 1) | (if set { 1UL } else { 0UL })
      } else if count == keep {
        guard_bit = set
      } else {
        sticky = sticky || set
      }
      count = (count + 1).min(keep + 2)
    }
  }
  if count < keep {
    mantissa = mantissa << (keep - count)
  }
  if guard_bit && (sticky || (mantissa & 1UL) != 0UL) {
    mantissa += 1UL
  }
  let shift = (exponent - 52L).max(-1074L).to_int()
  let power = if shift >= -1022 {
    ((shift + 1023).to_uint64() << 52).reinterpret_as_double()
  } else {
    (1UL << (shift + 1074)).reinterpret_as_double()
  }
  let value = mantissa.to_double() * power
  Some(if negative { -value } else { value })
}

///|
fn wget_cookie_time(value : Double) -> Int64 {
  // The fixed linux/amd64 oracle returns INT64_MIN for non-finite and
  // out-of-range conversion. Express that profile without a host C cast.
  if !value.is_finite() ||
    value >= 9223372036854775808.0 ||
    value < -9223372036854775808.0 {
    -9223372036854775808L
  } else {
    value.to_int64()
  }
}

///|
fn wget_cookie_saved_time(value : Int64) -> String {
  let rounded = value.to_double()
  if rounded < 0.0 {
    "-" + (-rounded).to_uint64().to_string()
  } else {
    rounded.to_uint64().to_string()
  }
}
