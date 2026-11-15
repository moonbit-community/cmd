///|
async fn encoded_output(input : Bytes, wrap : Int32) -> Bytes {
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

///|
test "base64 byte encoding preserves every byte across fragmented quanta and wraps" {
  // Frozen GNU coreutils 9.11 output for the ascending 0..255 byte vector.
  let expected = b"AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn+AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6ChoqOkpaanqKmqq6ytrq+wsbKztLW2t7i5uru8vb6/wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbX2Nna29zd3t/g4eLj5OXm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+/w=="
  let input = Bytes::makei(256, i => i.to_byte())
  for size in [1, 2, 3, 4, 5, 7, 31, 255, 256] {
    for wrap in [0, 1, 3, 4, 5, 76, 344, 345, 2147483647] {
      let encoder = Base64Encoder::new(wrap)
      let chunks : Array[Bytes] = []
      for start = 0; start < input.length(); start = start + size {
        chunks.push(
          encoder.encode(input[start:(start + size).min(input.length())]),
        )
        assert_eq(encoder.encode(b""[:]), b"")
      }
      chunks.push(encoder.finish())
      let mut index = 0
      let mut column = 0
      for chunk in chunks {
        for byte in chunk {
          if byte == b'\n' {
            assert_true(
              wrap > 0 && (column == wrap || index == expected.length()),
            )
            column = 0
          } else {
            assert_eq(byte, expected[index])
            index += 1
            column += 1
          }
        }
      }
      assert_eq(index, expected.length())
      if wrap > 0 {
        assert_eq(column, 0)
      }
    }
  }
  for
    (input, expected) in [
      (b"", b""),
      (b"f", b"Zg=="),
      (b"fo", b"Zm8="),
      (b"foo", b"Zm9v"),
      (b"foob", b"Zm9vYg=="),
      (b"fooba", b"Zm9vYmE="),
      (b"foobar", b"Zm9vYmFy"),
    ] {
    let encoder = Base64Encoder::new(0)
    let first = encoder.encode(input[:])
    let tail = encoder.finish()
    assert_eq(first + tail, expected)
  }
}

///|
priv struct EncodingOutput {
  bytes : Array[Byte]
  mut calls : Int32
  fail_after : Int32
}

///|
impl @io.Writer for EncodingOutput with fn write_once(
  self,
  bytes,
  offset~,
  len~,
) {
  self.calls += 1
  guard self.calls <= self.fail_after else { fail("encoding write failed") }
  let count = len.min(3)
  for i in offset..<(offset + count) {
    self.bytes.push(bytes[i])
  }
  count
}

///|
async test "base64 emits complete quanta before later read errors and never replays failed writes" {
  let reader = @io.MemoryReader(writer => {
    writer.write(b"foob")
    fail("encoding read failed")
  })
  defer reader.close()
  let output : EncodingOutput = { bytes: [], calls: 0, fail_after: 100, }
  assert_true(
    try {
      encode_stream(reader, 0, writer=output)
      false
    } catch {
      _ => true
    },
  )
  assert_eq(Bytes::from_array(output.bytes), b"Zm9v")
  let reader2 = @io.MemoryReader(writer => writer.write(b"foobar"))
  defer reader2.close()
  let failed : EncodingOutput = { bytes: [], calls: 0, fail_after: 1, }
  assert_true(
    try {
      encode_stream(reader2, 0, writer=failed)
      false
    } catch {
      _ => true
    },
  )
  assert_eq(Bytes::from_array(failed.bytes), b"Zm9")
  assert_eq(failed.calls, 2)
}

///|
async test "base64 stream carry crosses the full read boundary without inserting padding" {
  let input = Bytes::makei(65535, i => b"foo"[i % 3]) + b"b"
  let expected = Bytes::makei(87380, i => b"Zm9v"[i % 4]) + b"Yg=="
  assert_eq(encoded_output(input, 0), expected)
}
