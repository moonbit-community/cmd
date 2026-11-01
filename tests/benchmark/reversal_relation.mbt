///|
// This independent relation applies only to ASCII records, preserving each LF
// and the final unterminated record. It is outside every timed interval.
async fn ascii_reversal_expected(source : String, target : String) -> Bool {
  if @fs.exists(target) {
    return true
  }
  let input = @fs.open(source, mode=ReadOnly)
  defer input.close()
  let output = @fs.create(target, allow_existing=false)
  defer output.close()
  let buffer = FixedArray::make(65536, b'\x00')
  let bytes = buffer.unsafe_reinterpret_as_bytes()
  let record : Array[Byte] = []
  while input.read(buffer) is count && count > 0 {
    for byte in bytes[:count] {
      if byte.to_int() > 127 {
        output.close()
        @fs.remove(target)
        return false
      }
      if byte == b'\n' {
        output.write(
          Bytes::makei(record.length() + 1, i => {
            if i == record.length() {
              b'\n'
            } else {
              record[record.length() - 1 - i]
            }
          }),
        )
        record.clear()
      } else {
        guard record.length() < 8388608 else {
          fail("independent reversal record bound exceeded")
        }
        record.push(byte)
      }
    }
  }
  if !record.is_empty() {
    output.write(
      Bytes::makei(record.length(), i => record[record.length() - 1 - i]),
    )
  }
  true
}
