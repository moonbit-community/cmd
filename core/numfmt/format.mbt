///|
fn hexadecimal(
  coefficient : BigInt,
  exponent : Int32,
  precision : Int32?,
  alternate : Bool,
  upper : Bool,
  profile : Profile,
  normalized : Bool,
) -> String {
  let (bits, minimum, _) = limits(profile)
  let leading_bits = if profile is Extended80 && !normalized { 4 } else { 1 }
  let fraction_digits = (bits - leading_bits + 3) / 4
  let mut displayed_exponent = if coefficient.is_zero() {
    0
  } else {
    Int32::max(coefficient.bit_length() - 1 + exponent, minimum) -
    leading_bits +
    1
  }
  let shift = exponent - displayed_exponent + 4 * fraction_digits
  let significand = if coefficient.is_zero() {
    coefficient
  } else if shift >= 0 {
    coefficient << shift
  } else {
    coefficient >> -shift
  }
  let places = precision.unwrap_or(fraction_digits)
  let rounded = if places < fraction_digits {
    rounded_quotient(
      significand,
      BigInt::from_int(1) << (4 * (fraction_digits - places)),
    ).0
  } else {
    significand << (4 * (places - fraction_digits))
  }
  let rounded = if leading_bits == 4 && rounded.bit_length() > 4 * places + 4 {
    displayed_exponent += 1
    rounded >> 1
  } else {
    rounded
  }
  let text = rounded.to_string(radix=16)
  let text = "0".repeat(Int32::max(places + 1 - text.length(), 0)) + text
  let split = text.length() - places
  let mut fraction = text[split:].to_owned()
  if precision is None {
    while fraction.has_suffix("0") {
      fraction = fraction[:fraction.length() - 1].to_owned()
    }
  }
  let point = if fraction != "" ||
    alternate ||
    (places > 0 && precision is Some(_)) {
    "."
  } else {
    ""
  }
  let magnitude = (if upper { "0X" } else { "0x" }) +
    text[:split].to_owned() +
    point +
    fraction +
    (if upper { "P" } else { "p" }) +
    (if displayed_exponent < 0 { "" } else { "+" }) +
    displayed_exponent.to_string()
  if upper {
    magnitude.to_upper()
  } else {
    magnitude
  }
}

///|
/// Match GNU ftoastr's general-format precision search, including its normal
/// minimum precision and shorter subnormal search.
pub fn format_roundtrip(value : Value, profile : Profile) -> String {
  let sign = if value.is_negative() { "-" } else { "" }
  guard value is Finite(_, coefficient, exponent) else {
    return sign + format_magnitude(value, 'g', None, false, profile)
  }
  let (bits, minimum, _) = limits(profile)
  let start = if coefficient.is_zero() ||
    coefficient.bit_length() - 1 + exponent < minimum {
    1
  } else {
    (bits - 1) * 30103 / 100000
  }
  let bound = (bits * 146 + 484) / 485 + 1
  for precision = start; ; precision = precision + 1 {
    let text = sign +
      format_magnitude(value, 'g', Some(precision), false, profile)
    if precision >= bound || compare(parse_prefix(text, profile).0, value) == 0 {
      return text
    }
  }
}

///|
pub fn format_magnitude(
  value : Value,
  conversion : Char,
  precision : Int32?,
  alternate : Bool,
  profile : Profile,
  normalized_hex~ : Bool = true,
) -> String {
  let upper = conversion is ('A' | 'E' | 'F' | 'G')
  match value {
    NaN(_) => if upper { "NAN" } else { "nan" }
    Infinity(_) => if upper { "INF" } else { "inf" }
    Finite(_, coefficient, exponent) =>
      if conversion is ('a' | 'A') {
        hexadecimal(
          coefficient, exponent, precision, alternate, upper, profile, normalized_hex,
        )
      } else {
        let decimal = dec_of_dyadic(coefficient, exponent)
        let precision = precision.unwrap_or(6)
        match conversion {
          'f' | 'F' => fmt_f(decimal, precision, alternate)
          'e' | 'E' => fmt_e(decimal, precision, alternate, upper)
          _ => fmt_g(decimal, precision, alternate, upper)
        }
      }
  }
}
