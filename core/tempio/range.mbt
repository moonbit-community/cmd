///|
/// Copy a known file extent using caller-owned scratch storage. Every read and
/// write completes before that storage is reused. A shortened extent is an error.
pub async fn copy_range(
  file : @fs.File,
  start : Int64,
  end : Int64,
  buffer : FixedArray[Byte],
  writer : &@io.Writer,
) -> Unit {
  guard start >= 0L && end >= start && buffer.length() > 0 else {
    raise TemporaryError("invalid file extent or empty copy buffer")
  }
  let mut position = start
  while position < end {
    let length = (end - position).min(buffer.length().to_int64()).to_int()
    let count = file.read_at(buffer, position~, len=length)
    if count != length {
      raise @io.ReaderClosed
    }
    writer.write(buffer.unsafe_reinterpret_as_bytes()[:count])
    position += count.to_int64()
  }
}
