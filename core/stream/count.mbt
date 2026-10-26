///|
/// Count a byte in immutable storage without copying it into a vector buffer.
/// The lane-local zero mask avoids cross-byte borrows counting adjacent 0x01
/// bytes as matches. Wide loads are bounded by the view, including its offset.
pub fn count_byte(data : BytesView, needle : Byte) -> Int32 {
  let bytes = data.data()
  let mut offset = data.start_offset()
  let end = offset + data.length()
  let repeated = needle.to_uint64() * 0x0101010101010101UL
  let low = 0x7F7F7F7F7F7F7F7FUL
  let mut count = 0
  while end - offset >= 8 {
    let value = bytes.unsafe_read_uint64_le(offset) ^ repeated
    let zeroes = (((value & low) + low) | value | low) ^ 0xFFFFFFFFFFFFFFFFUL
    count += zeroes.popcnt()
    offset += 8
  }
  while offset < end {
    if bytes[offset] == needle {
      count += 1
    }
    offset += 1
  }
  count
}
