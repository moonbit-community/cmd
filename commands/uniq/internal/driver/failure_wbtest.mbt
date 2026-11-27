///|
priv struct CapturedBytes {
  controller : @io.BinaryWriterController
  data : @buffer.Buffer
}

///|
impl @io.BinaryWriter for CapturedBytes

///|
impl @io.BinaryWriterImpl for CapturedBytes with fn name(_) {
  "CapturedBytes"
}

///|
impl @io.BinaryWriterImpl for CapturedBytes with fn get_controller(self) {
  self.controller
}

///|
impl @io.BinaryWriterImpl for CapturedBytes with fn flush_partial_data(_) {
  ()
}

///|
impl @io.BinaryWriterImpl for CapturedBytes with fn raw_write_impl(
  self,
  bytes,
  offset~,
  len~,
) {
  self.data.write_bytesview(bytes[offset:offset + len])
  len
}

///|
async test "uniq read errors flush completed groups without finalizing the pending group" {
  let reader = @io.MemoryReader(writer => {
    writer.write(b"alpha\nalpha\nbeta\nfragment")
    fail("injected input failure")
  })
  defer reader.close()
  let output = CapturedBytes::{
    controller: @io.BinaryWriterController(),
    data: @buffer.Buffer(),
  }
  let failed = try {
    process_reader(
      reader,
      false,
      false,
      false,
      false,
      0,
      0,
      None,
      b'\n',
      Summarize,
      writer=output,
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  assert_eq(output.data.to_bytes(), b"alpha\n")
}

///|
async test "uniq keeps a retained key across large input blocks" {
  let line = Bytes::make(1048583, b'x')
  assert_eq(
    uniq_output(line + b"\n" + line + b"\ntail", Summarize),
    line + b"\ntail\n",
  )
}
