///|
priv suberror CommError {
  CommError(String)
}

///|
fn help_message() -> String {
  let message =
    #|Usage: comm [-123] [-z] FILE1 FILE2
    #|  -h, --help      display this help and exit
    #|      --version   display version and exit
    #|
    #|Compare two sorted files line by line, producing three columns:
    #|lines only in FILE1, lines only in FILE2, and lines in both.
    #|
    #|Options:
    #|  -1  Suppress column 1 (lines unique to FILE1).
    #|  -2  Suppress column 2 (lines unique to FILE2).
    #|  -3  Suppress column 3 (lines in both files).
    #|      --output-delimiter=STR  Separate columns with STR (empty means NUL).
    #|      --total  Print counts for all three columns and a total label.
    #|      --check-order  Diagnose unsorted input.
    #|      --nocheck-order  Do not diagnose unsorted input.
    #|  -z, --zero-terminated  End records with NUL instead of newline.
    #|
    #|Use '-' as a file name to read stdin.
    #|
    #|Project aliases: --suppress-1 = -1; --suppress-2 = -2; --suppress-3 = -3.
    #|-h is a project alias of --help.
    #|
    #|Ordinary option/operand errors exit 1; documented capability refusals retain their own status.
  message
}

///|
fn comm_record(prefix : Bytes, line : Bytes, delimiter : Byte) -> Bytes {
  let output = @buffer.Buffer(size_hint=prefix.length() + line.length() + 1)
  output.write_bytes(prefix)
  output.write_bytes(line)
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
    output: @buffer.Buffer(size_hint=65536),
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
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("comm 0.2.7\n")
    return
  }
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("suppress-1", short='1'),
    @cli.flag("suppress-2", short='2'),
    @cli.flag("suppress-3", short='3'),
    @cli.option("output-delimiter"),
    @cli.flag("total"),
    @cli.flag("help", short='h'),
    @cli.flag("check-order"),
    @cli.flag("nocheck-order"),
    @cli.flag("zero-terminated", short='z'),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("comm: \{message}: '\{option}'\n")
      @sys.exit(1)
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
      @sys.exit(1)
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
    @sys.exit(1)
    return
  }
  if files[0] == "-" && files[1] == "-" {
    @stdio.stderr.write("comm: both inputs cannot be standard input\n")
    @sys.exit(1)
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
      @sys.exit(1)
      return
    }
    err => {
      @stdio.stderr.write("comm: \{err}\n")
      @sys.exit(1)
      return
    }
  }
}
