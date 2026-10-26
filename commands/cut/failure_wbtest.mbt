///|
priv struct CapturedBytes {
  data : @buffer.Buffer
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
