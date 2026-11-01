///|
priv struct CommOutput {
  bytes : Array[Byte]
}

///|
impl @io.Writer for CommOutput with fn write_once(self, bytes, offset~, len~) {
  for i in offset..<(offset + len) {
    self.bytes.push(bytes[i])
  }
  len
}

///|
async test "comm columns suppression and totals retain record separators" {
  for zero in [false, true] {
    let delimiter = if zero { b'\x00' } else { b'\n' }
    let left = @io.MemoryReader(writer => {
      writer.write(if zero { b"a\x00c" } else { b"a\nc" })
    })
    defer left.close()
    let right = @io.MemoryReader(writer => {
      writer.write(if zero { b"b\x00c" } else { b"b\nc" })
    })
    defer right.close()
    let output : CommOutput = { bytes: [], }
    merge_readers(
      left,
      right,
      false,
      false,
      false,
      -1,
      delimiter,
      ":",
      true,
      writer=output,
    )
    assert_eq(
      Bytes::from_array(output.bytes),
      if zero {
        b"a\x00:b\x00::c\x001:1:1:total\x00"
      } else {
        b"a\n:b\n::c\n1:1:1:total\n"
      },
    )
  }
}

///|
async test "comm retains the merged prefix when a later read fails" {
  let left = @io.MemoryReader(writer => {
    writer.write(b"one\ntwo\nfragment")
    fail("injected read failure")
  })
  defer left.close()
  let right = @io.MemoryReader(writer => writer.write(b"one\n"))
  defer right.close()
  let output : CommOutput = { bytes: [], }
  let failed = try {
    merge_readers(
      left,
      right,
      false,
      false,
      false,
      -1,
      b'\n',
      "\t",
      false,
      writer=output,
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  assert_eq(Bytes::from_array(output.bytes), b"\t\tone\ntwo\n")
}

///|
test "comm coalesced records preserve arbitrary column and record delimiters" {
  assert_eq(comm_record(b"\t\t", b"a\x00\xff", b'\n'), b"\t\ta\x00\xff\n")
  assert_eq(comm_record(b"", b"", b'\x00'), b"\x00")
  assert_eq(
    comm_record(@utf8.encode("界"), b"record", b'\x00'),
    @utf8.encode("界record\u0000"),
  )
}

///|
async test "comm borrowed merge preserves fragmented duplicates and suppression" {
  for chunk in [1, 2, 3, 7, 65536] {
    for mask in 0..<8 {
      let left = @io.MemoryReader(writer => {
        let bytes = b"a\na\nc\nd"
        for i = 0; i < bytes.length(); i = i + chunk {
          writer.write(bytes[i:(i + chunk).min(bytes.length())])
        }
      })
      defer left.close()
      let right = @io.MemoryReader(writer => {
        let bytes = b"a\nb\nc\nc\n"
        for i = 0; i < bytes.length(); i = i + chunk {
          writer.write(bytes[i:(i + chunk).min(bytes.length())])
        }
      })
      defer right.close()
      let h1 = (mask & 1) != 0
      let h2 = (mask & 2) != 0
      let h3 = (mask & 4) != 0
      let p2 = if h1 { "" } else { ":" }
      let p3 = p2 + (if h2 { "" } else { ":" })
      let expected = (if h3 { "" } else { p3 + "a\n" }) +
        (if h1 { "" } else { "a\n" }) +
        (if h2 { "" } else { p2 + "b\n" }) +
        (if h3 { "" } else { p3 + "c\n" }) +
        (if h2 { "" } else { p2 + "c\n" }) +
        (if h1 { "" } else { "d\n" }) +
        "2:2:2:total\n"
      let output : CommOutput = { bytes: [], }
      merge_readers(left, right, h1, h2, h3, 1, b'\n', ":", true, writer=output)
      assert_eq(Bytes::from_array(output.bytes), @utf8.encode(expected))
    }
  }
}

///|
priv struct CommFailOutput {
  bytes : Array[Byte]
}

///|
impl @io.Writer for CommFailOutput with fn write_once(
  self,
  bytes,
  offset~,
  len~,
) {
  if self.bytes.length() >= 17 {
    fail("injected partial output failure")
  }
  let count = len.min(17 - self.bytes.length())
  for i in offset..<(offset + count) {
    self.bytes.push(bytes[i])
  }
  count
}

///|
async test "comm oversized record output failure does not replay queued bytes" {
  let left = @io.MemoryReader(writer => writer.write(Bytes::make(70000, b'a')))
  defer left.close()
  let right = @io.MemoryReader(_ => ())
  defer right.close()
  let output : CommFailOutput = { bytes: [], }
  let failed = try {
    merge_readers(
      left,
      right,
      false,
      false,
      false,
      -1,
      b'\n',
      "\t",
      false,
      writer=output,
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  assert_eq(Bytes::from_array(output.bytes), Bytes::make(17, b'a'))
}
