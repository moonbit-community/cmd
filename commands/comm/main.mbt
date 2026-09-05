///|
priv suberror CommError {
  CommError(String)
}

///|
fn help_message() -> String {
  let message =
    #|Usage: comm [-123] [-z] FILE1 FILE2
    #|
    #|Compare two sorted files line by line, producing three columns:
    #|lines only in FILE1, lines only in FILE2, and lines in both.
    #|
    #|Options:
    #|  -1  Suppress column 1 (lines unique to FILE1).
    #|  -2  Suppress column 2 (lines unique to FILE2).
    #|  -3  Suppress column 3 (lines in both files).
    #|      --check-order  Diagnose unsorted input.
    #|      --nocheck-order  Do not diagnose unsorted input.
    #|  -z, --zero-terminated  End records with NUL instead of newline.
    #|  -h, --help  Show this help message.
    #|
    #|Use '-' as a file name to read stdin.
  message
}

///|
async fn next_checked(
  scanner : @stream.LineScanner,
  previous : Ref[Bytes?],
  unordered : Ref[Bool],
  name : String,
  order_mode : Int,
  unpairable : Ref[Bool],
) -> @stream.Line? {
  let line = scanner.next()
  match line {
    Some(value) => {
      match previous.val {
        Some(old) if old[:].lexical_compare(value.data[:]) > 0 => {
          unordered.val = true
          if order_mode > 0 || (order_mode == 0 && unpairable.val) {
            raise CommError("\{name} is not in sorted order")
          }
        }
        _ => ()
      }
      previous.val = Some(value.data)
    }
    None => ()
  }
  line
}

///|
fn mark_unpairable(
  order_mode : Int,
  unpairable : Ref[Bool],
  unordered1 : Ref[Bool],
  unordered2 : Ref[Bool],
) -> Unit raise CommError {
  unpairable.val = true
  if order_mode == 0 && (unordered1.val || unordered2.val) {
    raise CommError("input is not in sorted order")
  }
}

///|
async fn write_line(prefix : String, line : Bytes, delimiter : Byte) -> Unit {
  if prefix != "" {
    @stdio.stdout.write(prefix)
  }
  @stdio.stdout.write(line)
  @stdio.stdout.write(Bytes::from_array([delimiter]))
}

///|
async fn merge_readers(
  reader1 : &@io.Reader,
  reader2 : &@io.Reader,
  hide1 : Bool,
  hide2 : Bool,
  hide3 : Bool,
  order_mode : Int,
  record_delimiter : Byte,
) -> Unit {
  let scanner1 = @stream.LineScanner::new(reader1, delimiter=record_delimiter)
  let scanner2 = @stream.LineScanner::new(reader2, delimiter=record_delimiter)
  let previous1 : Ref[Bytes?] = Ref(None)
  let previous2 : Ref[Bytes?] = Ref(None)
  let unordered1 = Ref(false)
  let unordered2 = Ref(false)
  let unpairable = Ref(false)
  let mut line1 = next_checked(
    scanner1, previous1, unordered1, "file 1", order_mode, unpairable,
  )
  let mut line2 = next_checked(
    scanner2, previous2, unordered2, "file 2", order_mode, unpairable,
  )
  let col2_prefix = if hide1 { "" } else { "\t" }
  let col3_prefix = (if hide1 { "" } else { "\t" }) +
    (if hide2 { "" } else { "\t" })
  while line1 is Some(left) && line2 is Some(right) {
    let order = left.data[:].lexical_compare(right.data[:])
    if order < 0 {
      mark_unpairable(order_mode, unpairable, unordered1, unordered2)
      if !hide1 {
        write_line("", left.data, record_delimiter)
      }
      line1 = next_checked(
        scanner1, previous1, unordered1, "file 1", order_mode, unpairable,
      )
    } else if order > 0 {
      mark_unpairable(order_mode, unpairable, unordered1, unordered2)
      if !hide2 {
        write_line(col2_prefix, right.data, record_delimiter)
      }
      line2 = next_checked(
        scanner2, previous2, unordered2, "file 2", order_mode, unpairable,
      )
    } else {
      if !hide3 {
        write_line(col3_prefix, left.data, record_delimiter)
      }
      line1 = next_checked(
        scanner1, previous1, unordered1, "file 1", order_mode, unpairable,
      )
      line2 = next_checked(
        scanner2, previous2, unordered2, "file 2", order_mode, unpairable,
      )
    }
  }
  while line1 is Some(left) {
    mark_unpairable(order_mode, unpairable, unordered1, unordered2)
    if !hide1 {
      write_line("", left.data, record_delimiter)
    }
    line1 = next_checked(
      scanner1, previous1, unordered1, "file 1", order_mode, unpairable,
    )
  }
  while line2 is Some(right) {
    mark_unpairable(order_mode, unpairable, unordered1, unordered2)
    if !hide2 {
      write_line(col2_prefix, right.data, record_delimiter)
    }
    line2 = next_checked(
      scanner2, previous2, unordered2, "file 2", order_mode, unpairable,
    )
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("suppress-1", short='1'),
    @cli.flag("suppress-2", short='2'),
    @cli.flag("suppress-3", short='3'),
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
  let order_mode = if parsed.contains("nocheck-order") {
    -1
  } else if parsed.contains("check-order") {
    1
  } else {
    0
  }
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
        @stdio.stdin, file2, hide1, hide2, hide3, order_mode, record_delimiter,
      )
    } else if files[1] == "-" {
      let file1 = @fs.open(files[0], mode=ReadOnly)
      defer file1.close()
      merge_readers(
        file1, @stdio.stdin, hide1, hide2, hide3, order_mode, record_delimiter,
      )
    } else {
      let file1 = @fs.open(files[0], mode=ReadOnly)
      defer file1.close()
      let file2 = @fs.open(files[1], mode=ReadOnly)
      defer file2.close()
      merge_readers(
        file1, file2, hide1, hide2, hide3, order_mode, record_delimiter,
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
