///|
pub(all) enum Profile {
  Binary16
  BFloat16
  Binary32
  Binary64
  Extended80
  Binary128
}

///|
pub(all) enum Value {
  Finite(Bool, BigInt, Int32)
  Infinity(Bool)
  NaN(Bool)
}

///|
fn limits(profile : Profile) -> (Int32, Int32, Int32) {
  match profile {
    Binary16 => (11, -14, 15)
    BFloat16 => (8, -126, 127)
    Binary32 => (24, -126, 127)
    Binary64 => (53, -1022, 1023)
    Extended80 => (64, -16382, 16383)
    Binary128 => (113, -16382, 16383)
  }
}

///|
pub fn zero(negative~ : Bool = false) -> Value {
  Finite(negative, BigInt::from_int(0), 0)
}

///|
pub fn Value::is_negative(self : Value) -> Bool {
  match self {
    Finite(sign, _, _) | Infinity(sign) | NaN(sign) => sign
  }
}

///|
fn rounded_quotient(numerator : BigInt, denominator : BigInt) -> (BigInt, Bool) {
  let quotient = numerator / denominator
  let remainder = numerator % denominator
  let order = (remainder << 1).compare(denominator)
  let odd = !(quotient % BigInt::from_int(2)).is_zero()
  (
    if order > 0 || (order == 0 && odd) {
      quotient + BigInt::from_int(1)
    } else {
      quotient
    },
    !remainder.is_zero(),
  )
}

///|
fn round_ratio(
  negative : Bool,
  numerator : BigInt,
  denominator : BigInt,
  profile : Profile,
) -> (Value, Bool) {
  if numerator.is_zero() {
    return (zero(negative~), false)
  }
  let (precision, minimum, maximum) = limits(profile)
  let mut leading = numerator.bit_length() - denominator.bit_length()
  let lower = if leading >= 0 {
    numerator.compare(denominator << leading) < 0
  } else {
    (numerator << -leading).compare(denominator) < 0
  }
  if lower {
    leading -= 1
  }
  if leading > maximum {
    return (Infinity(negative), true)
  }
  let mut exponent = Int32::max(
    leading - precision + 1,
    minimum - precision + 1,
  )
  let (scaled_numerator, scaled_denominator) = if exponent >= 0 {
    (numerator, denominator << exponent)
  } else {
    (numerator << -exponent, denominator)
  }
  let (rounded, inexact) = rounded_quotient(
    scaled_numerator, scaled_denominator,
  )
  if rounded.is_zero() {
    return (zero(negative~), true)
  }
  let mut coefficient = rounded
  if coefficient.bit_length() > precision {
    coefficient = coefficient >> 1
    exponent += 1
  }
  if coefficient.bit_length() - 1 + exponent > maximum {
    return (Infinity(negative), true)
  }
  let range_error = leading < minimum && inexact
  let trailing = coefficient.ctz()
  (Finite(negative, coefficient >> trailing, exponent + trailing), range_error)
}

///|
fn round_dyadic(
  negative : Bool,
  coefficient : BigInt,
  exponent : Int32,
  profile : Profile,
) -> Value {
  let (numerator, denominator) = if exponent >= 0 {
    (coefficient << exponent, BigInt::from_int(1))
  } else {
    (coefficient, BigInt::from_int(1) << -exponent)
  }
  round_ratio(negative, numerator, denominator, profile).0
}

///|
fn word_at(chars : Array[Char], index : Int32, word : String) -> Bool {
  let wanted = word.iter().collect()
  if index + wanted.length() > chars.length() {
    return false
  }
  for offset, expected in wanted {
    let actual = chars[index + offset]
    let actual = if actual is ('A'..<='Z') {
      (actual.to_int() + 32).unsafe_to_char()
    } else {
      actual
    }
    if actual != expected {
      return false
    }
  }
  true
}

///|
fn digit_value(character : Char, radix : Int32) -> Int32 {
  let value = match character {
    '0'..<='9' => character.to_int() - 0x30
    'a'..<='f' => character.to_int() - 0x61 + 10
    'A'..<='F' => character.to_int() - 0x41 + 10
    _ => -1
  }
  if value < radix {
    value
  } else {
    -1
  }
}

///|
/// Parse the C numeric prefix. A zero consumed length means no conversion;
/// the final flag reports overflow or inexact underflow in the chosen profile.
pub fn parse_prefix(text : String, profile : Profile) -> (Value, Int32, Bool) {
  let chars = text.iter().collect()
  let mut index = 0
  while index < chars.length() &&
        chars[index] is (' ' | '\t' | '\n' | '\r' | '\u000b' | '\u000c') {
    index += 1
  }
  let mut negative = false
  if index < chars.length() && chars[index] is ('+' | '-') {
    negative = chars[index] == '-'
    index += 1
  }
  for spelling in ["infinity", "inf"] {
    if word_at(chars, index, spelling) {
      return (Infinity(negative), index + spelling.length(), false)
    }
  }
  if word_at(chars, index, "nan") {
    let mut end = index + 3
    if end < chars.length() && chars[end] == '(' {
      let mut next = end + 1
      while next < chars.length() &&
            chars[next] is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '_') {
        next += 1
      }
      if next < chars.length() && chars[next] == ')' {
        end = next + 1
      }
    }
    return (NaN(negative), end, false)
  }
  let start = index
  let hex = index + 2 < chars.length() &&
    chars[index] == '0' &&
    chars[index + 1] is ('x' | 'X') &&
    (digit_value(chars[index + 2], 16) >= 0 || chars[index + 2] == '.')
  let radix = if hex { 16 } else { 10 }
  if hex {
    index += 2
  }
  let digits = StringBuilder()
  let mut fraction = false
  let mut places = 0
  while index < chars.length() {
    if digit_value(chars[index], radix) >= 0 {
      digits.write_char(chars[index])
      if fraction {
        places += 1
      }
      index += 1
    } else if chars[index] == '.' && !fraction {
      fraction = true
      index += 1
    } else {
      break
    }
  }
  if digits.is_empty() {
    return if hex {
      (zero(negative~), start + 1, false)
    } else {
      (zero(), 0, false)
    }
  }
  let mut exponent = 0
  if index < chars.length() &&
    (if hex {
      chars[index] is ('p' | 'P')
    } else {
      chars[index] is ('e' | 'E')
    }) {
    let mut next = index + 1
    let mut sign = 1
    if next < chars.length() && chars[next] is ('+' | '-') {
      if chars[next] == '-' {
        sign = -1
      }
      next += 1
    }
    let first_digit = next
    while next < chars.length() && chars[next] is ('0'..<='9') {
      exponent = Int32::min(
        1000000,
        exponent * 10 + chars[next].to_int() - 0x30,
      )
      next += 1
    }
    if next > first_digit {
      exponent *= sign
      index = next
    } else {
      exponent = 0
    }
  }
  let mut coefficient = BigInt::from_string(digits.to_string(), radix~)
  if coefficient.is_zero() {
    return (zero(negative~), index, false)
  }
  let (numerator, denominator) = if hex {
    let exponent = exponent - 4 * places
    let leading = coefficient.bit_length() - 1 + exponent
    let (_, minimum, maximum) = limits(profile)
    if leading > maximum + 1 {
      return (Infinity(negative), index, true)
    }
    if leading < minimum - 120 {
      return (zero(negative~), index, true)
    }
    if exponent >= 0 {
      (coefficient << exponent, BigInt::from_int(1))
    } else {
      (coefficient, BigInt::from_int(1) << -exponent)
    }
  } else {
    let mut exponent = exponent - places
    let ten = BigInt::from_int(10)
    while (coefficient % ten).is_zero() {
      coefficient = coefficient / ten
      exponent += 1
    }
    let magnitude = coefficient.to_string().length() + exponent
    if magnitude > 6000 {
      return (Infinity(negative), index, true)
    }
    if magnitude < -6000 {
      return (zero(negative~), index, true)
    }
    if exponent >= 0 {
      (coefficient * ten.pow(BigInt::from_int(exponent)), BigInt::from_int(1))
    } else {
      (coefficient, ten.pow(BigInt::from_int(-exponent)))
    }
  }
  let (value, range_error) = round_ratio(
    negative, numerator, denominator, profile,
  )
  (value, index, range_error)
}

///|
pub fn compare(left : Value, right : Value) -> Int32 {
  match (left, right) {
    (NaN(_), _) | (_, NaN(_)) => 0
    (Infinity(a), Infinity(b)) => if a == b { 0 } else if a { -1 } else { 1 }
    (Infinity(negative), _) => if negative { -1 } else { 1 }
    (_, Infinity(negative)) => if negative { 1 } else { -1 }
    (
      Finite(sign1, coefficient1, exponent1),
      Finite(sign2, coefficient2, exponent2),
    ) => {
      if coefficient1.is_zero() && coefficient2.is_zero() {
        return 0
      }
      if sign1 != sign2 {
        return if sign1 { -1 } else { 1 }
      }
      let exponent = Int32::min(exponent1, exponent2)
      let order = (coefficient1 << (exponent1 - exponent)).compare(
        coefficient2 << (exponent2 - exponent),
      )
      if sign1 {
        -order
      } else {
        order
      }
    }
  }
}

///|
pub fn sequence_value(
  first : Value,
  step : Value,
  index : BigInt,
  profile : Profile,
) -> Value {
  let index = round_dyadic(false, index, 0, profile)
  match (first, step, index) {
    (
      Finite(sign1, coefficient1, exponent1),
      Finite(sign2, coefficient2, exponent2),
      Finite(_, count, count_exponent),
    ) => {
      let product = round_dyadic(
        sign2,
        coefficient2 * count,
        exponent2 + count_exponent,
        profile,
      )
      guard product
        is Finite(product_sign, product_coefficient, product_exponent) else {
        return product
      }
      let exponent = Int32::min(exponent1, product_exponent)
      let left = coefficient1 << (exponent1 - exponent)
      let right = product_coefficient << (product_exponent - exponent)
      let sum = (if sign1 { -left } else { left }) +
        (if product_sign { -right } else { right })
      let negative = sum.compare_int(0) < 0 ||
        (sum.is_zero() && sign1 && product_sign)
      round_dyadic(
        negative,
        if negative {
          -sum
        } else {
          sum
        },
        exponent,
        profile,
      )
    }
    (Infinity(sign), _, _) => Infinity(sign)
    (_, Infinity(sign), _) => Infinity(sign)
    _ => NaN(false)
  }
}
