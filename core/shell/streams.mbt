///|
priv struct CaptureBuffer {
  bytes : Array[Byte]
}

///|
impl @io.Writer for CaptureBuffer with fn write_once(self, data, offset~, len~) {
  for index in offset..<(offset + len) {
    self.bytes.push(data[index])
  }
  len
}

///|
fn CaptureBuffer::text(self : CaptureBuffer) -> String raise ShellError {
  @utf8.decode(Bytes::from_array(self.bytes)) catch {
    _ => raise ShellError("command substitution output is not valid UTF-8")
  }
}

///|
fn output_writer(context : Context) -> &@io.Writer {
  match context.output {
    Some(writer) => writer
    None =>
      match context.capture {
        Some(buffer) => return buffer
        None => return @stdio.stdout
      }
  }
}

///|
fn error_writer(context : Context) -> &@io.Writer {
  context.error.unwrap_or(@stdio.stderr)
}
