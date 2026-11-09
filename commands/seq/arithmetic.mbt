///|
fn limits(profile : @numfmt.Profile) -> (Int32, Int32, Int32) {
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
  profile : @numfmt.Profile,
) -> (@numfmt.Value, Bool) {
  if numerator.is_zero() {
    return (@numfmt.zero(negative~), false)
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
    return (@numfmt.zero(negative~), true)
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
  profile : @numfmt.Profile,
) -> @numfmt.Value {
  let (numerator, denominator) = if exponent >= 0 {
    (coefficient << exponent, BigInt::from_int(1))
  } else {
    (coefficient, BigInt::from_int(1) << -exponent)
  }
  round_ratio(negative, numerator, denominator, profile).0
}

///|
fn compare_binary(left : @numfmt.Value, right : @numfmt.Value) -> Int32 {
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
fn sequence_value(
  first : @numfmt.Value,
  step : @numfmt.Value,
  index : BigInt,
  profile : @numfmt.Profile,
) -> @numfmt.Value {
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
