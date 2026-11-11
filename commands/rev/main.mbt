///|
let command : @argparse.Command = @argparse.Command(
  "rev",
  flags=[@argparse.FlagArg("help")],
  positionals=[
    @argparse.PositionArg("operands", num_args=@argparse.ValueRange()),
  ],
  disable_help_flag=true,
  disable_version_flag=true,
  disable_help_subcommand=true,
)

///|
priv suberror InvalidCRecord {
  InvalidCRecord
}

///|
priv struct RevOutput {
  writer : &@io.Writer
  buffer : FixedArray[Byte]
  mut length : Int32
  mut pending : (BytesView, Bool, Int32)?
  count : Ref[Int64]
  mut failed : Bool
}

///|
async fn RevOutput::flush(self : RevOutput) -> Unit {
  let length = self.length
  self.length = 0
  errdefer {
    self.failed = true
  }
  if length > 0 {
    self.writer.write(self.buffer.unsafe_reinterpret_as_bytes()[:length])
  }
}

///|
// Copy backwards into a fixed output buffer. Suspend only at a full buffer;
// count a record after its terminator is buffered, exactly as BufferedWriter.
fn RevOutput::append(
  self : RevOutput,
  data : BytesView,
  terminated : Bool,
  remaining : Int32,
) -> Bool {
  let copied = remaining.min(self.buffer.length() - self.length)
  let mut index = 0
  // A big-endian store reverses the eight bytes of a little-endian load.
  // Both accesses stay within this record view and the free output span.
  while copied - index >= 8 {
    self.buffer.unsafe_write_uint64_be(
      self.length + index,
      data.unsafe_read_uint64_le(remaining - index - 8),
    )
    index += 8
  }
  while index < copied {
    self.buffer[self.length + index] = data[remaining - index - 1]
    index += 1
  }
  self.length += copied
  let remaining = remaining - copied
  if remaining > 0 || (terminated && self.length == self.buffer.length()) {
    self.pending = Some((data, terminated, remaining))
    return false
  }
  if terminated {
    self.buffer[self.length] = b'\n'
    self.length += 1
  }
  self.count.val += 1L
  self.pending = None
  true
}

///|
fn invalid_c_record(data : BytesView) -> Bool {
  let mut index = 0
  while data.length() - index >= 8 {
    if (data.unsafe_read_uint64_le(index) & 0x8080808080808080UL) != 0UL {
      return true
    }
    index += 8
  }
  while index < data.length() {
    if data[index].to_int() >= 128 {
      return true
    }
    index += 1
  }
  false
}

///|
fn help_message() -> String {
  let message =
    #|Usage: rev [OPTION]... [FILE]...
    #|      --help      display this help and exit
    #|      --version   display version and exit
    #|
    #|Reverse each line from ordered FILE operands, or standard input if absent.
    #|The fixed Linux C-locale profile reverses bytes and rejects non-ASCII records.
    #|An explicit - is a filename, as in the frozen util-linux profile.
    #|Input streams one record at a time; memory follows the longest record.
    #|
    #|Ordinary option/operand errors exit 1; documented capability refusals retain their own status.
  message
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("rev \{MODULE_VERSION}\n")
    return
  }
  let parsed = command.parse(argv=@env.args()[1:], env=Map([])) catch {
    error => {
      let text = error.to_string()
      let line = match text.rev_find("' found") {
        Some(end) => text[:end + 7]
        None => text.split("\n").next().unwrap_or(text[:])
      }
      let (message, option) = match line {
        [.. "error: unexpected argument '--", .. rest] => {
          let spelling = rest.strip_suffix("' found").unwrap_or(rest)
          let name = spelling.split("=").next().unwrap_or(spelling).to_owned()
          let message = if spelling.contains("=") && ["help"].contains(name) {
            "flag does not accept a value"
          } else {
            "unknown option"
          }
          (message, name)
        }
        [.. "error: unexpected argument '-", .. rest] =>
          (
            "unknown short option",
            rest.strip_suffix("' found").unwrap_or(rest).to_owned(),
          )
        _ => (text, "")
      }
      @stdio.stderr.write("rev: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  let operands = parsed.values.get("operands").unwrap_or([])
  if parsed.flags.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  if operands.is_empty() {
    let lines = Ref(0L)
    reverse_reader(@stdio.stdin, lines) catch {
      error => {
        @stdio.stderr.write(
          "rev: stdin: " +
          lines.val.to_string() +
          ": " +
          error_message(error) +
          "\n",
        )
        @sys.exit(1)
      }
    }
    return
  }
  let mut status = 0
  for path in operands {
    let mut opened = false
    let lines = Ref(0L)
    try {
      let file = @fs.open(path, mode=ReadOnly)
      opened = true
      defer file.close()
      if file.kind() == @fs.FileKind::Directory {
        @stdio.stderr.write("rev: " + path + ": 0: Is a directory\n")
        status = 1
      } else {
        reverse_reader(file, lines)
      }
    } catch {
      error => {
        let prefix = if opened {
          "rev: " + path + ": " + lines.val.to_string() + ": "
        } else {
          "rev: cannot open " + path + ": "
        }
        @stdio.stderr.write(prefix + error_message(error) + "\n")
        status = 1
      }
    }
  }
  if status != 0 {
    @sys.exit(status)
  }
}

///|
async fn reverse_reader(
  reader : &@io.Reader,
  count : Ref[Int64],
  writer~ : &@io.Writer = @stdio.stdout,
) -> Unit {
  let lines = @stream.RecordReader::new(reader)
  let output : RevOutput = {
    writer,
    buffer: FixedArray::make(65536, b'\x00'),
    length: 0,
    pending: None,
    count,
    failed: false,
  }
  let mut invalid = false
  let consume = (data : BytesView, terminated : Bool) => {
    if invalid_c_record(data) {
      invalid = true
      false
    } else {
      output.append(data, terminated, data.length())
    }
  }
  let processing_error = try {
    while lines.next_batch() is Some(batch) {
      while !batch.each_while(consume) {
        if invalid {
          raise InvalidCRecord
        }
        output.flush()
        while output.pending is Some((data, terminated, remaining)) {
          if !output.append(data, terminated, remaining) {
            output.flush()
          }
        }
      }
    }
    None
  } catch {
    error => Some(error)
  }
  if !output.failed {
    output.flush()
  }
  if processing_error is Some(error) {
    raise error
  }
}

///|
fn error_message(error : Error) -> String {
  match error {
    InvalidCRecord => "Invalid or incomplete multibyte or wide character"
    @os_error.OSError(code, ..) as error =>
      if error.is_ENOENT() {
        "No such file or directory"
      } else if error.is_EACCES() {
        "Permission denied"
      } else if error.is_ENOTDIR() {
        "Not a directory"
      } else if !@platform.is_windows() && code == 21 {
        "Is a directory"
      } else if !@platform.is_windows() && code == 9 {
        "Bad file descriptor"
      } else {
        error.to_string()
      }
    _ => error.to_string()
  }
}
