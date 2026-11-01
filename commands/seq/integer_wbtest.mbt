///|
fn integer_text(
  first : Int64,
  step : Int64,
  last : Int64,
  separator~ : String = "\n",
  width~ : Int32 = 0,
  capacity~ : Int32 = 64,
) -> String raise {
  let sequence = IntegerSequence::new(
    first,
    step,
    last,
    @utf8.encode(separator),
    width,
  )
  let buffer = FixedArray::make(capacity, b'\x00')
  let result : Array[Byte] = []
  while !sequence.done {
    let count = sequence.fill(buffer)
    assert_true(count > 0 || sequence.done)
    for i in 0..<count {
      result.push(buffer[i])
    }
  }
  @utf8.decode(Bytes::from_array(result))
}

///|
test "seq integer batches preserve signs widths separators endpoints and overflow" {
  assert_eq(integer_text(1L, 1L, 4L), "1\n2\n3\n4\n")
  assert_eq(
    integer_text(-3L, 2L, 4L, separator="界", width=3),
    "-03界-01界001界003\n",
  )
  assert_eq(integer_text(3L, -2L, -4L, separator=""), "31-1-3\n")
  assert_eq(integer_text(2L, 1L, 1L), "")
  assert_eq(integer_text(1L, -1L, 2L), "")
  assert_eq(
    integer_text(9223372036854775806L, 2L, 9223372036854775807L),
    "9223372036854775806\n",
  )
  assert_eq(
    integer_text(-9223372036854775807L, -2L, -9223372036854775808L),
    "-9223372036854775807\n",
  )
  assert_eq(
    integer_text(0L, -9223372036854775808L, -9223372036854775808L),
    "0\n-9223372036854775808\n",
  )
  assert_eq(
    integer_text(
      -9223372036854775808L, 9223372036854775807L, 9223372036854775807L,
    ),
    "-9223372036854775808\n-1\n9223372036854775806\n",
  )
  for capacity in [22, 23, 31, 64, 257] {
    for
      (first, step, last) in [(-53L, 7L, 91L), (91L, -7L, -53L), (0L, 1L, 257L)] {
      let expected = StringBuilder()
      for value = first
          (if step > 0 { value <= last } else { value >= last })
          value = value + step {
        expected.write_string(value.to_string() + "\n")
      }
      assert_eq(
        integer_text(first, step, last, capacity~),
        expected.to_string(),
      )
    }
  }
}

///|
test "seq bounded integer admission preserves exact decimal and large integer fallback" {
  for
    text in [
      "-9223372036854775808", "9223372036854775807", "12.000", "1e3", "-0",
    ] {
    let number = parse_decimal(text)
    guard number.bounded_integer() is Some(value) else { fail(text) }
    assert_eq(BigInt::from_int64(value), number.coefficient)
  }
  for
    text in [
      "-9223372036854775809", "9223372036854775808", "0.1", "1e-4096", "1e4096",
    ] {
    assert_true(parse_decimal(text).bounded_integer() is None)
  }
}

///|
priv struct SequenceSink {
  bytes : Array[Byte]
  mut calls : Int32
}

///|
impl @io.Writer for SequenceSink with fn write_once(self, bytes, offset~, len~) {
  self.calls += 1
  if self.calls > 1 {
    fail("sequence write failed")
  }
  let count = len.min(3)
  for i in offset..<(offset + count) {
    self.bytes.push(bytes[i])
  }
  count
}

///|
async test "seq integer output propagates partial write failure without replay" {
  let sink : SequenceSink = { bytes: [], calls: 0, }
  let sequence = IntegerSequence::new(1L, 1L, 1000000L, b"\n", 0)
  assert_true(
    try {
      print_integers(sequence, sink)
      false
    } catch {
      _ => true
    },
  )
  assert_eq(Bytes::from_array(sink.bytes), b"1\n2")
  assert_eq(sink.calls, 2)
}
