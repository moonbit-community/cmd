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
  message
}

///|
priv struct CommOrder {
  mut previous : Bytes?
  mut descending : Bool
  mut warned : Bool
}

///|
async fn next_checked(
  output : @stream.BlockWriter,
  scanner : @stream.LineScanner,
  state : CommOrder,
  name : String,
  order_mode : Int32,
  unpairable : Ref[Bool],
) -> @stream.Line? {
  let line = scanner.next()
  if line is Some(value) {
    state.descending = match state.previous {
      Some(old) => old[:].lexical_compare(value.data[:]) > 0
      None => false
    }
    state.previous = Some(value.data)
  }
  // At EOF GNU checks the final pair again after observing an unpaired row.
  if !state.warned &&
    state.descending &&
    (order_mode > 0 || (order_mode == 0 && unpairable.val)) {
    output.flush()
    if order_mode > 0 {
      raise CommError("\{name} is not in sorted order")
    }
    @stdio.stderr.write("comm: \{name} is not in sorted order\n")
    state.warned = true
  }
  line
}

///|
async fn write_line(
  writer : &@io.Writer,
  prefix : String,
  line : Bytes,
  delimiter : Byte,
) -> Unit {
  if prefix != "" {
    writer.write(prefix)
  }
  writer.write(line)
  writer.write(Bytes::from_array([delimiter]))
}

///|
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
  let output = @stream.BlockWriter::new(writer)
  defer output.flush()
  let scanner1 = @stream.LineScanner::new(reader1, delimiter=record_delimiter)
  let scanner2 = @stream.LineScanner::new(reader2, delimiter=record_delimiter)
  let state1 : CommOrder = { previous: None, descending: false, warned: false, }
  let state2 : CommOrder = { previous: None, descending: false, warned: false, }
  let unpairable = Ref(false)
  let mut line1 = next_checked(
    output, scanner1, state1, "file 1", order_mode, unpairable,
  )
  let mut line2 = next_checked(
    output, scanner2, state2, "file 2", order_mode, unpairable,
  )
  let col2_prefix = if hide1 { "" } else { column_delimiter }
  let col3_prefix = (if hide1 { "" } else { column_delimiter }) +
    (if hide2 { "" } else { column_delimiter })
  let mut count1 : Int64 = 0
  let mut count2 : Int64 = 0
  let mut count3 : Int64 = 0
  while line1 is Some(left) && line2 is Some(right) {
    let order = left.data[:].lexical_compare(right.data[:])
    if order < 0 {
      unpairable.val = true
      count1 += 1
      if !hide1 {
        write_line(output, "", left.data, record_delimiter)
      }
      line1 = next_checked(
        output, scanner1, state1, "file 1", order_mode, unpairable,
      )
    } else if order > 0 {
      unpairable.val = true
      count2 += 1
      if !hide2 {
        write_line(output, col2_prefix, right.data, record_delimiter)
      }
      line2 = next_checked(
        output, scanner2, state2, "file 2", order_mode, unpairable,
      )
    } else {
      count3 += 1
      if !hide3 {
        write_line(output, col3_prefix, left.data, record_delimiter)
      }
      line1 = next_checked(
        output, scanner1, state1, "file 1", order_mode, unpairable,
      )
      line2 = next_checked(
        output, scanner2, state2, "file 2", order_mode, unpairable,
      )
    }
  }
  while line1 is Some(left) {
    unpairable.val = true
    count1 += 1
    if !hide1 {
      write_line(output, "", left.data, record_delimiter)
    }
    line1 = next_checked(
      output, scanner1, state1, "file 1", order_mode, unpairable,
    )
  }
  while line2 is Some(right) {
    unpairable.val = true
    count2 += 1
    if !hide2 {
      write_line(output, col2_prefix, right.data, record_delimiter)
    }
    line2 = next_checked(
      output, scanner2, state2, "file 2", order_mode, unpairable,
    )
  }
  if total {
    write_line(
      output,
      "\{count1}\{column_delimiter}\{count2}\{column_delimiter}\{count3}\{column_delimiter}",
      b"total",
      record_delimiter,
    )
  }
  if state1.warned || state2.warned {
    raise CommError("input is not in sorted order")
  }
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("comm 0.2.3\n")
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
      @sys.exit(2)
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
    @sys.exit(2)
    return
  }
  if files[0] == "-" && files[1] == "-" {
    @stdio.stderr.write("comm: both inputs cannot be standard input\n")
    @sys.exit(2)
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
