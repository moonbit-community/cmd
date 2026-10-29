///|
/// Preserve rg's printer and error contracts over the shared bounded writer.
pub struct StdoutWriter {
  priv output : @stream.BlockWriter
}

///|
priv struct StdoutSink {
  writer : &@io.Writer
}

///|
// Translate operating-system errors at the I/O boundary, outside the frequent
// buffered writes performed by the color and match printers.
impl @io.Writer for StdoutSink with fn write_once(self, bytes, offset~, len~) {
  self.writer.write_once(bytes, offset~, len~) catch {
    error => raise @sys.from_error(error)
  }
}

///|
fn StdoutWriter::new(line_buffered : Bool) -> StdoutWriter {
  {
    output: @stream.BlockWriter::new(
      StdoutSink::{ writer: @stdio.stdout, },
      line_buffered~,
    ),
  }
}

///|
pub impl @termcolor.Write for StdoutWriter with fn write_slice(
  self,
  data,
  start,
  end,
) {
  self.output.write_slice(data, start, end)
}

///|
pub impl @termcolor.Write for StdoutWriter with fn try_write_slice(
  self,
  data,
  start,
  end,
) {
  self.output.try_write_slice(data, start, end)
}

///|
pub impl @termcolor.Write for StdoutWriter with fn write_bytes(self, bytes) {
  self.output.write_bytes(bytes)
}

///|
pub impl @termcolor.Write for StdoutWriter with fn flush(self) {
  self.output.flush()
}
