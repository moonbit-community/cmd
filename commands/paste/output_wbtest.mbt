///|
priv struct PasteOutput {
  bytes : Array[Byte]
}

///|
impl @io.Writer for PasteOutput with fn write_once(self, bytes, offset~, len~) {
  for i in offset..<(offset + len) {
    self.bytes.push(bytes[i])
  }
  len
}

///|
async test "paste serial delimiters and repeated input ownership preserve bytes" {
  for serial in [true, false] {
    let reader = @io.MemoryReader(writer => writer.write(b"a\x00b\x00\xfftail"))
    defer reader.close()
    let scanner = @stream.LineScanner::new(reader, delimiter=b'\x00')
    let output : PasteOutput = { bytes: [], }
    if serial {
      paste_serial(scanner, [b",", b""], b'\x00', writer=output)
    } else {
      paste_parallel([scanner, scanner], [b","], b'\x00', writer=output)
    }
    assert_eq(
      Bytes::from_array(output.bytes),
      if serial {
        b"a,b\xfftail\x00"
      } else {
        b"a,b\x00\xfftail,\x00"
      },
    )
  }
}

///|
async test "paste preserves the emitted prefix on input failure" {
  for serial in [true, false] {
    let reader = @io.MemoryReader(writer => {
      writer.write(b"one\nfragment")
      fail("injected read failure")
    })
    defer reader.close()
    let scanner = @stream.LineScanner::new(reader)
    let output : PasteOutput = { bytes: [], }
    let failed = try {
      if serial {
        paste_serial(scanner, [b","], b'\n', writer=output)
      } else {
        paste_parallel([scanner], [b","], b'\n', writer=output)
      }
      false
    } catch {
      _ => true
    }
    assert_true(failed)
    assert_eq(
      Bytes::from_array(output.bytes),
      if serial {
        b"one"
      } else {
        b"one\n"
      },
    )
  }
}
