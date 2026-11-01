///|
// Strategy: sort-fractional-fields

///|
// Borrow decimal digits without converting them to a bounded numeric type.
priv struct DecimalKey {
  negative : Bool
  integer : BytesView
  fraction : BytesView
}

///|
fn decimal_key(key : BytesView) -> DecimalKey {
  let mut i = 0
  while i < key.length() && byte_is_blank(key[i]) {
    i += 1
  }
  let negative = i < key.length() && key[i] == b'-'
  if negative {
    i += 1
  }
  while i < key.length() && key[i] == b'0' {
    i += 1
  }
  let start = i
  while i < key.length() && byte_is_digit(key[i]) {
    i += 1
  }
  let integer = key[start:i]
  if i < key.length() && key[i] == b'.' {
    i += 1
  }
  let fraction_start = i
  while i < key.length() && byte_is_digit(key[i]) {
    i += 1
  }
  while i > fraction_start && key[i - 1] == b'0' {
    i -= 1
  }
  let fraction = key[fraction_start:i]
  {
    negative: negative && (integer.length() > 0 || fraction.length() > 0),
    integer,
    fraction,
  }
}

///|
fn DecimalKey::compare(self : DecimalKey, other : DecimalKey) -> Int32 {
  if self.negative != other.negative {
    return if self.negative { -1 } else { 1 }
  }
  let mut order = self.integer.length().compare(other.integer.length())
  if order == 0 {
    order = self.integer.lexical_compare(other.integer)
  }
  if order == 0 {
    order = self.fraction.lexical_compare(other.fraction)
  }
  if self.negative {
    -order
  } else {
    order
  }
}

///|
fn numeric_compare(left : Bytes, right : Bytes) -> Int32 {
  // This fast path is exact for at most fifteen integer digits on each side.
  match (integral_prefix(left), integral_prefix(right)) {
    (Some(left), Some(right)) => left.compare(right)
    _ => decimal_key(left).compare(decimal_key(right))
  }
}

///|
// Run records retain canonical digits, not rounded Double bits. The private
// header stores sign and integer length; input bytes cannot masquerade as it.
fn prepare_numeric_field(key : BytesView) -> Bytes {
  let number = decimal_key(key)
  let output = @buffer.Buffer(
    size_hint=5 + number.integer.length() + number.fraction.length(),
  )
  output.write_byte(if number.negative { b'\x01' } else { b'\x00' })
  output.write_int_le(number.integer.length())
  output.write_bytes(number.integer)
  output.write_bytes(number.fraction)
  output.to_bytes()
}

///|
fn numeric_field_value(key : Bytes) -> DecimalKey {
  let length = key[1].to_int() |
    (key[2].to_int() << 8) |
    (key[3].to_int() << 16) |
    (key[4].to_int() << 24)
  {
    negative: key[0] == b'\x01',
    integer: key[5:5 + length],
    fraction: key[5 + length:],
  }
}
