///|
priv struct ShellCapture {
  bytes : Array[Byte]
}

///|
impl @io.Writer for ShellCapture with fn write_once(self, data, offset~, len~) {
  for index in offset..<(offset + len) {
    self.bytes.push(data[index])
  }
  len
}

///|
async fn capture_shell(
  script : String,
  environment : Map[String, String],
  cwd : String,
  error~ : &@io.Writer = @stdio.stderr,
) -> (Int32, String) {
  let output : ShellCapture = { bytes: [], }
  let session = @shell.Session::new(
    name="make",
    env=environment,
    cwd~,
    output~,
    error~,
  )
  let status = execute_shell(session, script, error~)
  let mut length = output.bytes.length()
  for index, byte in output.bytes {
    if byte == 0 {
      length = index
      break
    }
  }
  let text = @utf8.decode(Bytes::from_array(output.bytes[:length])) catch {
    _ => raise MakeError("shell output before its first NUL is not valid UTF-8")
  }
  (status, text)
}

///|
async fn execute_shell(
  session : @shell.Session,
  script : String,
  error~ : &@io.Writer = @stdio.stderr,
) -> Int32 {
  try {
    match session.feed(script) {
      Exit(status) | Completed(status) => status
      NeedMoreInput =>
        match session.finish() {
          Exit(status) | Completed(status) => status
          NeedMoreInput => raise MakeError("shell session did not finish")
        }
    }
  } catch {
    @shell.ShellError(message) => {
      // A shell-language error is the shell's exit status, not a make variable
      // expansion error. Keep bytes already written by that shell invocation.
      error.write("sh: \{message}\n")
      2
    }
    error => raise error
  }
}
