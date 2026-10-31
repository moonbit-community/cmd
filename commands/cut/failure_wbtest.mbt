///|
priv struct CapturedBytes {
  data : @buffer.Buffer
}

///|
async test "cut single range preserves clipping byte offsets and final delimiters" {
  for record_delimiter in [b'\n', b'\x00'] {
    for (lo, hi) in [(1, 1), (1, 8), (2, 9), (7, 14), (2, open_end)] {
      let input = @buffer.Buffer()
      let expected = @buffer.Buffer()
      for length in 0..<32 {
        let line = Bytes::makei(length, index => (32 + index * 3).to_byte())
        input.write_bytes(line)
        input.write_byte(record_delimiter)
        for index in 0..<line.length() {
          if index + 1 >= lo && index + 1 <= hi {
            expected.write_byte(line[index])
          }
        }
        expected.write_byte(record_delimiter)
      }
      input.write_bytes(b"tail")
      for index in 0..<4 {
        if index + 1 >= lo && index + 1 <= hi {
          expected.write_byte(b"tail"[index])
        }
      }
      expected.write_byte(record_delimiter)
      let reader = @io.MemoryReader(writer => writer.write(input.to_bytes()))
      defer reader.close()
      let output = CapturedBytes::{ data: @buffer.Buffer(), }
      process_reader(
        reader,
        None,
        Some([(lo, hi)]),
        b'\t',
        record_delimiter,
        false,
        Some(b"!"),
        writer=output,
      )
      assert_eq(output.data.to_bytes(), expected.to_bytes())
    }
  }
}

///|
impl @io.Writer for CapturedBytes with fn write_once(self, bytes, offset~, len~) {
  self.data.write_bytes(bytes[offset:offset + len])
  len
}

///|
async test "cut flushes completed records and drops the fragment on a read error" {
  let reader = @io.MemoryReader(writer => {
    writer.write(b"alpha\nbeta\nfragment")
    fail("injected input failure")
  })
  defer reader.close()
  let output = CapturedBytes::{ data: @buffer.Buffer(), }
  let failed = try {
    process_reader(
      reader,
      None,
      Some([(1, 2)]),
      b'\t',
      b'\n',
      false,
      None,
      writer=output,
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  assert_eq(output.data.to_bytes(), b"al\nbe\n")
}
