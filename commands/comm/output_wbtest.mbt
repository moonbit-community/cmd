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
