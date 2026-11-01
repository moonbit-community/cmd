///|
// Strategy: sort-fractional-fields

///|
// Explicit fields already own prepared bytes. Cache only prefixes that need
// the general decimal conversion; ordinary integers and global keys retain
// their allocation and comparison paths. Run framing treats these as bytes.
fn prepare_numeric_field(key : Bytes) -> Bytes {
  if !(key.length() == 9 && key[0] == b'\xff') &&
    integral_prefix(key) is Some(_) {
    return key
  }
  // The integral scan above already rejected this prefix. Avoid repeating it.
  let value = match numeric_slice(key, false, false) {
    Some(number) =>
      @string.parse_double(@utf8.decode(number)) catch {
        _ => 0.0
      }
    None => 0.0
  }
  let bits = value.reinterpret_as_uint64()
  let encoded = FixedArray::make(9, b'\x00')
  encoded[0] = b'\xff'
  for i in 0..<8 {
    encoded[i + 1] = (bits >> (i * 8)).to_byte()
  }
  encoded.unsafe_reinterpret_as_bytes()
}

///|
fn numeric_field_value(key : Bytes) -> Double {
  if key.length() == 9 && key[0] == b'\xff' {
    let mut bits = 0UL
    for i in 0..<8 {
      bits = bits | (key[i + 1].to_uint64() << (i * 8))
    }
    bits.reinterpret_as_double()
  } else {
    numeric_prefix(key, false)
  }
}
