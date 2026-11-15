///|
priv struct DecodeOutput {
  bytes : Array[Byte]
  mut calls : Int32
  fail_after : Int32
}

///|
impl @io.Writer for DecodeOutput with fn write_once(self, bytes, offset~, len~) {
  self.calls += 1
  guard self.calls <= self.fail_after else { fail("decode output failed") }
  let count = len.min(2)
  for index in offset..<(offset + count) {
    self.bytes.push(bytes[index])
  }
  count
}

///|
async test "base32 GNU 9.11 final padding and failure prefixes" {
  // Independently specified by coreutils v9.11 tests/basenc/basenc.pl and
  // the pinned gnulib decode_8 canonical-tail and partial-output contract.
  for
    (input, expected, invalid) in [
      (b"MFRGG", b"abc", false),
      (b"MFRGG===", b"abc", false),
      (b"MFRGGZDFMFRGG", b"abcdeabc", false),
      (b"IE", b"A", false),
      (b"IFBA", b"AB", false),
      (b"IFBEG", b"ABC", false),
      (b"IFBA====\nIE", b"ABA", false),
      (b"IFBA====\nIFBA====", b"ABAB", false),
      (b"MFRGGZDF=", b"abcde", true),
      (b"MZ======", b"f", true),
      (b"MZXR====", b"fo", true),
      (b"MZXW7===", b"foo", true),
      (b"MZXW6YR=", b"foob", true),
      (b"MY=", b"", true),
      (b"MFRGGZDFMY=", b"abcde", true),
      (b"MY!", b"f", true),
    ] {
    let output : DecodeOutput = { bytes: [], calls: 0, fail_after: 100, }
    let rejected = try {
      decode_to_writer(input, false, output)
      false
    } catch {
      CliError(message) => {
        assert_eq(message, "base32: invalid input")
        true
      }
    }
    assert_eq(rejected, invalid)
    assert_eq(Bytes::from_array(output.bytes), expected)
  }
}

///|
async test "base32 failure-prefix output errors are never replayed" {
  for input in [b"MFRGGZDF!", b"MFRGGZ=="] {
    let output : DecodeOutput = { bytes: [], calls: 0, fail_after: 1, }
    assert_true(
      try {
        decode_to_writer(input, false, output)
        false
      } catch {
        CliError(message) => {
          assert_true(message.contains("decode output failed"))
          true
        }
      },
    )
    assert_eq(Bytes::from_array(output.bytes), b"ab")
    assert_eq(output.calls, 2)
  }
}
