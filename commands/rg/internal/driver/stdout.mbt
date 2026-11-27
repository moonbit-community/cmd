///|
/// Preserve rg's printer and error contracts over the shared bounded writer.
pub struct StdoutWriter {
  priv output : @stream.BlockWriter
}

///|
fn StdoutWriter::new(line_buffered : Bool) -> StdoutWriter {
  { output: @stream.BlockWriter::from_binary(@stdio.stdout, line_buffered~), }
}

///|
pub impl @termcolor.Write for StdoutWriter with fn write_slice(
  self,
  data,
  start,
  end,
) {
  self.output.write_slice(data, start, end) catch {
    @io.WriterError::TransportError(cause, ..) =>
      raise @sys.from_error(@stream.transport_cause(cause))
    error => raise error
  }
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
  self.output.write_bytes(bytes) catch {
    @io.WriterError::TransportError(cause, ..) =>
      raise @sys.from_error(@stream.transport_cause(cause))
    error => raise error
  }
}

///|
pub impl @termcolor.Write for StdoutWriter with fn flush(self) {
  self.output.flush() catch {
    @io.WriterError::TransportError(cause, ..) =>
      raise @sys.from_error(@stream.transport_cause(cause))
    error => raise error
  }
}
