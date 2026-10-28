///|
priv struct FailingStdout {
  calls : Ref[Int32]
}

///|
impl @io.Writer for FailingStdout with fn write_once(self, _, offset~, len~) {
  ignore((offset, len))
  self.calls.val += 1
  raise @os_error.OSError(32, context="injected output failure")
}

///|
async test "shared stdout translates I/O errors once and never replays on cleanup" {
  let sink = FailingStdout::{ calls: Ref(0), }
  let writer : StdoutWriter = {
    output: @stream.BlockWriter::new(StdoutSink::{ writer: sink, }, size=8),
  }
  @termcolor.Write::write_bytes(writer, b"queued")
  assert_eq(sink.calls.val, 0)
  let converted = try {
    defer @termcolor.Write::flush(writer)
    @termcolor.Write::flush(writer)
    false
  } catch {
    @sys.IOError(..) as error => {
      assert_eq(
        error.kind(),
        @sys.from_error(
          @os_error.OSError(32, context="injected output failure"),
        ).kind(),
      )
      true
    }
    _ => false
  }
  assert_true(converted)
  assert_eq(sink.calls.val, 1)
}
