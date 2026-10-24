///|
/// Decode a frozen-profile element. Short elements are padded with physical
/// trailing zeros; Extended80 uses the selected 16-byte x87 storage slot.
pub fn decode(
  data : BytesView,
  profile : Profile,
  big_endian~ : Bool = false,
) -> Value {
  let size = match profile {
    Binary16 | BFloat16 => 2
    Binary32 => 4
    Binary64 => 8
    Extended80 | Binary128 => 16
  }
  let bytes = Bytes::makei(size, index => {
    let source = if big_endian { index } else { size - index - 1 }
    if source < data.length() {
      data[source]
    } else {
      b'\x00'
    }
  })
  let bits = BigInt::from_octets(bytes[:])
  let (fraction_bits, exponent_bits, bias, explicit_bit) = match profile {
    Binary16 => (10, 5, 15, false)
    BFloat16 => (7, 8, 127, false)
    Binary32 => (23, 8, 127, false)
    Binary64 => (52, 11, 1023, false)
    Extended80 => (63, 15, 16383, true)
    Binary128 => (112, 15, 16383, false)
  }
  let stored_significand = fraction_bits + (if explicit_bit { 1 } else { 0 })
  let exponent_mask = (BigInt::from_int(1) << exponent_bits) -
    BigInt::from_int(1)
  let exponent = ((bits >> stored_significand) & exponent_mask).to_int()
  let negative = !((bits >> (stored_significand + exponent_bits)) &
  BigInt::from_int(1)).is_zero()
  let fraction_mask = (BigInt::from_int(1) << fraction_bits) -
    BigInt::from_int(1)
  let fraction = bits & fraction_mask
  let integer_bit = if explicit_bit {
    !((bits >> fraction_bits) & BigInt::from_int(1)).is_zero()
  } else {
    exponent != 0
  }
  if exponent == (1 << exponent_bits) - 1 {
    return if fraction.is_zero() && integer_bit {
      Infinity(negative)
    } else {
      NaN(negative)
    }
  }
  if explicit_bit && exponent != 0 && !integer_bit {
    return NaN(negative)
  }
  let coefficient = if integer_bit {
    fraction | (BigInt::from_int(1) << fraction_bits)
  } else {
    fraction
  }
  if coefficient.is_zero() {
    return zero(negative~)
  }
  let trailing = coefficient.ctz()
  Finite(
    negative,
    coefficient >> trailing,
    (if exponent == 0 { 1 - bias } else { exponent - bias }) -
    fraction_bits +
    trailing,
  )
}
