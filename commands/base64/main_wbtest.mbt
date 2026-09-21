///|
async fn encoded_output(input : Bytes, wrap : Int) -> Bytes {
  let source = @io.MemoryReader(writer => writer.write(input))
  defer source.close()
  let encoded = @io.MemoryReader(writer => encode_stream(source, wrap, writer~))
  defer encoded.close()
  encoded.read_all().binary()
}

///|
async test "base64 zero wrap emits no terminal newline" {
  assert_eq(encoded_output(b"hello", 0), b"aGVsbG8=")
  assert_eq(encoded_output(b"hello", 76), b"aGVsbG8=\n")
  assert_eq(encoded_output(b"hello", 4), b"aGVs\nbG8=\n")
  assert_eq(encoded_output(b"", 0), b"")
}
