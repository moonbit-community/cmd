///|
test "base32 RFC 4648 vectors" {
  assert_eq(encode_bytes(b"", 0), b"")
  assert_eq(encode_bytes(b"f", 0), b"MY======")
  assert_eq(encode_bytes(b"fo", 0), b"MZXQ====")
  assert_eq(encode_bytes(b"foo", 0), b"MZXW6===")
  assert_eq(encode_bytes(b"foob", 0), b"MZXW6YQ=")
  assert_eq(encode_bytes(b"fooba", 0), b"MZXW6YTB")
  assert_eq(encode_bytes(b"foobar", 0), b"MZXW6YTBOI======")
}

///|
test "base32 decode vectors and wrapping" {
  let one : Array[Byte] = []
  decode_block(b"MY======".to_array(), one)
  assert_eq(Bytes::from_array(one), b"f")
  let three : Array[Byte] = []
  decode_block(b"MZXW6===".to_array(), three)
  assert_eq(Bytes::from_array(three), b"foo")
  let six : Array[Byte] = []
  decode_block(b"MZXW6YTB".to_array(), six)
  decode_block(b"OI======".to_array(), six)
  assert_eq(Bytes::from_array(six), b"foobar")
  assert_eq(encode_bytes(b"foobar", 8), b"MZXW6YTB\nOI======\n")
  assert_eq(encode_bytes(b"foobar", 0), b"MZXW6YTBOI======")
}

///|
test "base32 rejects lowercase and preserves decoded prefix" {
  let lowercase = try decode_block(b"my======".to_array(), []) catch {
    CliError(_) => b"rejected"
  } noraise {
    _ => b"accepted"
  }
  assert_eq(lowercase, b"rejected")
  let tail : Array[Byte] = []
  decode_block(b"MZ======".to_array(), tail)
  assert_eq(Bytes::from_array(tail), b"f")
  let prefix : Array[Byte] = []
  let result = try decode_block(b"MY=XXXXX".to_array(), prefix) catch {
    CliError(_) => b"rejected"
  } noraise {
    _ => b"accepted"
  }
  assert_eq(result, b"rejected")
  assert_eq(Bytes::from_array(prefix), b"f")
}
