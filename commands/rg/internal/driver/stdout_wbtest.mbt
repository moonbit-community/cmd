///|
priv struct FailingStdout {
  controller : @io.BinaryWriterController
  calls : Ref[Int32]
}

///|
impl @io.BinaryWriter for FailingStdout

///|
impl @io.BinaryWriterImpl for FailingStdout with fn name(_) {
  "FailingStdout"
}

///|
impl @io.BinaryWriterImpl for FailingStdout with fn get_controller(self) {
  self.controller
}

///|
impl @io.BinaryWriterImpl for FailingStdout with fn flush_partial_data(_) {
  ()
}

///|
impl @io.BinaryWriterImpl for FailingStdout with fn raw_write_impl(
  self,
  _,
  offset~,
  len~,
) {
  ignore((offset, len))
  self.calls.val += 1
  raise @os_error.from_errno(32, context="injected output failure")
}

///|
async test "shared stdout translates I/O errors once and never replays on cleanup" {
  let sink = FailingStdout::{
    controller: @io.BinaryWriterController(),
    calls: Ref(0),
  }
  let writer : StdoutWriter = {
    output: @stream.BlockWriter::from_binary(sink, size=8),
  }
  @termcolor.Write::write_bytes(writer, b"queued")
  assert_eq(sink.calls.val, 0)
  let converted = try {
    defer @async.protect_from_cancel(() => @termcolor.Write::flush(writer))
    @termcolor.Write::flush(writer)
    false
  } catch {
    @sys.IoError(..) as error => {
      assert_eq(
        error.kind(),
        if @sys.is_windows() {
          Other
        } else {
          BrokenPipe
        },
      )
      true
    }
    _ => false
  }
  assert_true(converted)
  assert_eq(sink.calls.val, 1)
}
