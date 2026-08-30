///|
fn help_message() -> String {
  let message =
    #|Usage: comm [-123] FILE1 FILE2
    #|
    #|Compare two sorted files line by line, producing three columns:
    #|lines only in FILE1, lines only in FILE2, and lines in both.
    #|
    #|Options:
    #|  -1  Suppress column 1 (lines unique to FILE1).
    #|  -2  Suppress column 2 (lines unique to FILE2).
    #|  -3  Suppress column 3 (lines in both files).
    #|  -h, --help  Show this help message.
    #|
    #|Use '-' as a file name to read stdin.
  message
}

///|
async fn write_line(prefix : String, line : Bytes) -> Unit {
  if prefix != "" {
    @stdio.stdout.write(prefix)
  }
  @stdio.stdout.write(line)
  @stdio.stdout.write("\n")
}

///|
async fn merge_readers(
  reader1 : &@io.Reader,
  reader2 : &@io.Reader,
  hide1 : Bool,
  hide2 : Bool,
  hide3 : Bool,
) -> Unit {
  let scanner1 = @stream.LineScanner::new(reader1)
  let scanner2 = @stream.LineScanner::new(reader2)
  let mut line1 = scanner1.next()
  let mut line2 = scanner2.next()
  let col2_prefix = if hide1 { "" } else { "\t" }
  let col3_prefix = (if hide1 { "" } else { "\t" }) +
    (if hide2 { "" } else { "\t" })
  while line1 is Some(left) && line2 is Some(right) {
    let order = left.data[:].lexical_compare(right.data[:])
    if order < 0 {
      if !hide1 {
        write_line("", left.data)
      }
      line1 = scanner1.next()
    } else if order > 0 {
      if !hide2 {
        write_line(col2_prefix, right.data)
      }
      line2 = scanner2.next()
    } else {
      if !hide3 {
        write_line(col3_prefix, left.data)
      }
      line1 = scanner1.next()
      line2 = scanner2.next()
    }
  }
  while line1 is Some(left) {
    if !hide1 {
      write_line("", left.data)
    }
    line1 = scanner1.next()
  }
  while line2 is Some(right) {
    if !hide2 {
      write_line(col2_prefix, right.data)
    }
    line2 = scanner2.next()
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
      merge_readers(@stdio.stdin, file2, hide1, hide2, hide3)
    } else if files[1] == "-" {
      let file1 = @fs.open(files[0], mode=ReadOnly)
      defer file1.close()
      merge_readers(file1, @stdio.stdin, hide1, hide2, hide3)
    } else {
      let file1 = @fs.open(files[0], mode=ReadOnly)
      defer file1.close()
      let file2 = @fs.open(files[1], mode=ReadOnly)
      defer file2.close()
      merge_readers(file1, file2, hide1, hide2, hide3)
    }
  } catch {
    err => {
      @stdio.stderr.write("comm: \{err}\n")
      @sys.exit(1)
      return
    }
  }
}
