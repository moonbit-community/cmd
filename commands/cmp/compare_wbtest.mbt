///|
async fn quiet_comparison(
  a : Bytes,
  b : Bytes,
  left_chunk~ : Int32,
  right_chunk~ : Int32,
  limit~ : Int64? = None,
  skips~ : (Int64, Int64) = (0L, 0L),
) -> Bool {
  let left = @io.MemoryReader(writer => {
    for offset = 0; offset < a.length(); offset = offset + left_chunk {
      writer.write(a[offset:(offset + left_chunk).min(a.length())])
    }
  })
  defer left.close()
  let right = @io.MemoryReader(writer => {
    for offset = 0; offset < b.length(); offset = offset + right_chunk {
      writer.write(b[offset:(offset + right_chunk).min(b.length())])
    }
  })
  defer right.close()
  compare_readers(
    left,
    right,
    "left",
    "right",
    true,
    false,
    limit,
    skips.0,
    skips.1,
    false,
    1,
  )
}

///|
async test "cmp quiet chunks preserve skips limits binary data and unequal EOF" {
  let data = Bytes::makei(65539, i => (i % 251).to_byte())
  for (a, b) in [(1, 7), (257, 65536), (65536, 4093)] {
    assert_true(!quiet_comparison(data, data, left_chunk=a, right_chunk=b))
    assert_true(
      quiet_comparison(data, data + b"x", left_chunk=a, right_chunk=b),
    )
    assert_true(
      !quiet_comparison(
        data,
        data + b"x",
        left_chunk=a,
        right_chunk=b,
        limit=Some(data.length().to_int64()),
      ),
    )
    assert_true(
      !quiet_comparison(
        b"a" + data,
        b"bb" + data,
        left_chunk=a,
        right_chunk=b,
        skips=(1L, 2L),
      ),
    )
  }
  assert_true(
    !quiet_comparison(b"a", b"b", left_chunk=1, right_chunk=1, limit=Some(0L)),
  )
  assert_true(!quiet_comparison(b"", b"", left_chunk=1, right_chunk=1))
  for offset in [0, 1, 255, 65535, 65536, 65538] {
    let changed = FixedArray::makei(data.length(), i => {
      if i == offset {
        b'\xff'
      } else {
        data[i]
      }
    })
    assert_true(
      quiet_comparison(
        data,
        changed.unsafe_reinterpret_as_bytes(),
        left_chunk=4093,
        right_chunk=257,
      ),
    )
    assert_true(
      !quiet_comparison(
        data,
        changed.unsafe_reinterpret_as_bytes(),
        left_chunk=4093,
        right_chunk=257,
        limit=Some(offset.to_int64()),
      ),
    )
  }
}

///|
async test "cmp quiet mismatch returns before a later read failure" {
  let left = @io.MemoryReader(writer => {
    writer.write(b"left")
    writer.write(b"unread")
    fail("late left read")
  })
  defer left.close()
  let right = @io.MemoryReader(writer => {
    writer.write(b"right")
    writer.write(b"unread")
    fail("late right read")
  })
  defer right.close()
  assert_true(
    compare_readers(
      left,
      right,
      "left",
      "right",
      true,
      false,
      None,
      0L,
      0L,
      false,
      1,
    ),
  )
}
