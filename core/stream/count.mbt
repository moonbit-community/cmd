///|
/// Preserve the stream API while sharing ownership of byte-search kernels.
pub fn count_byte(data : BytesView, needle : Byte) -> Int32 {
  @bytesearch.count_byte(data, needle)
}
