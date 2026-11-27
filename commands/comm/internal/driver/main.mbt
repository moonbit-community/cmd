///|
priv suberror CommError {
  CommError(String)
}

///|
fn help_message() -> String {
  let message = metadata_help().strip_suffix("\n").unwrap().to_owned()
  message
}

///|
fn comm_record(prefix : Bytes, line : Bytes, delimiter : Byte) -> Bytes {
  let output = @buffer.Buffer(capacity=prefix.length() + line.length() + 1)
  output.write_bytesview(prefix)
  output.write_bytesview(line)
  output.write_byte(delimiter)
  output.to_bytes()
}

///|
// Deferred output remains cancellable if the downstream writer stalls.
#warnings("-cancellable_defer")
async fn merge_readers(
  reader1 : &@io.Reader,
  reader2 : &@io.Reader,
  hide1 : Bool,
  hide2 : Bool,
  hide3 : Bool,
  order_mode : Int32,
  record_delimiter : Byte,
  column_delimiter : String,
  total : Bool,
  writer~ : &@io.Writer = @stdio.stdout,
) -> Unit {
  let left = CommInput::new(reader1, record_delimiter)
  let right = CommInput::new(reader2, record_delimiter)
  let prefix2 = if hide1 { b"" } else { @utf8.encode(column_delimiter) }
  let prefix3 = @utf8.encode(
    (if hide1 { "" } else { column_delimiter }) +
    (if hide2 { "" } else { column_delimiter }),
  )
  let merger : CommMerge = {
    left,
    right,
    hide1,
    hide2,
    hide3,
    order_mode,
    record_delimiter,
    prefix2,
    prefix3,
    unpairable: false,
    count1: 0,
    count2: 0,
    count3: 0,
    output: @buffer.Buffer(capacity=65536),
  }
  defer @stream.flush_buffer(writer, merger.output)
  for ;; {
    let action = merger.pump()
    @stream.flush_buffer(writer, merger.output)
    match action {
      Read(input) => {
        input.batch = input.records.next_batch()
        input.eof = input.batch is None
      }
      Warn(input, name) => {
        if order_mode > 0 {
          raise CommError("\{name} is not in sorted order")
        }
        @stdio.stderr.write("comm: \{name} is not in sorted order\n")
        input.warned = true
      }
      Flush => ()
      Done => break
    }
  }
  if total {
    writer.write(
      comm_record(
        @utf8.encode(
          "\{merger.count1}\{column_delimiter}\{merger.count2}\{column_delimiter}\{merger.count3}\{column_delimiter}",
        ),
        b"total",
        record_delimiter,
      ),
    )
  }
  if left.warned || right.warned {
    raise CommError("input is not in sorted order")
  }
}

///|
pub async fn run_main() -> Unit {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("comm \{MODULE_VERSION}\n")
    return
  }
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, option_specs()) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("comm: \{message}: '\{option}'\n")
      @env.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  let hide1 = parsed.contains("suppress-1")
  let hide2 = parsed.contains("suppress-2")
  let hide3 = parsed.contains("suppress-3")
  let order_mode = match
    parsed.last_occurrence(["check-order", "nocheck-order"]) {
    Some("nocheck-order") => -1
    Some(_) => 1
    None => 0
  }
  let delimiters = parsed.values("output-delimiter")
  let mut column_delimiter = "\t"
  for index, value in delimiters {
    if index > 0 && value != delimiters[0] {
      @stdio.stderr.write("comm: multiple output delimiters specified\n")
      @env.exit(1)
      return
    }
    column_delimiter = if value == "" { "\u0000" } else { value }
  }
  let total = parsed.contains("total")
  let record_delimiter = if parsed.contains("zero-terminated") {
    b'\x00'
  } else {
    b'\n'
  }
  let files = parsed.operands
  if files.length() != 2 {
    @stdio.stderr.write(
      "comm: expected exactly two files\n\n" + help_message() + "\n",
    )
    @env.exit(1)
    return
  }
  if files[0] == "-" && files[1] == "-" {
    @stdio.stderr.write("comm: both inputs cannot be standard input\n")
    @env.exit(1)
    return
  }
  try {
    if files[0] == "-" {
      let file2 = @fs.open(files[1], mode=ReadOnly)
      defer file2.close()
      merge_readers(
        @stdio.stdin, file2, hide1, hide2, hide3, order_mode, record_delimiter, column_delimiter,
        total,
      )
    } else if files[1] == "-" {
      let file1 = @fs.open(files[0], mode=ReadOnly)
      defer file1.close()
      merge_readers(
        file1, @stdio.stdin, hide1, hide2, hide3, order_mode, record_delimiter, column_delimiter,
        total,
      )
    } else {
      let file1 = @fs.open(files[0], mode=ReadOnly)
      defer file1.close()
      let file2 = @fs.open(files[1], mode=ReadOnly)
      defer file2.close()
      merge_readers(
        file1, file2, hide1, hide2, hide3, order_mode, record_delimiter, column_delimiter,
        total,
      )
    }
  } catch {
    CommError(message) => {
      @stdio.stderr.write("comm: \{message}\n")
      @env.exit(1)
      return
    }
    err => {
      @stdio.stderr.write("comm: \{err}\n")
      @env.exit(1)
      return
    }
  }
}
