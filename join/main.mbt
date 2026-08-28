///|
fn help_message() -> String {
  let message =
    #|Usage: join [options] FILE1 FILE2
    #|
    #|Join lines of two files sorted on their join fields.
    #|Only pairable lines are printed (no -a support yet).
    #|
    #|Options:
    #|  -1 FIELD    Join on this field of FILE1 (default 1).
    #|  -2 FIELD    Join on this field of FILE2 (default 1).
    #|  -t CHAR     Use CHAR as the field separator instead of runs of
    #|              blanks; the output separator becomes CHAR as well.
    #|  -h, --help  Show this help message.
    #|
    #|Use '-' as a file name to read stdin.
  message
}

///|
fn split_fields(line : Bytes, separator : Byte?) -> Array[Bytes] {
  match separator {
    Some(separator) => {
      let fields : Array[Bytes] = []
      let mut start = 0
      for index = 0; index < line.length(); index = index + 1 {
        if line[index] == separator {
          fields.push(line[start:index].to_owned())
          start = index + 1
        }
      }
      fields.push(line[start:].to_owned())
      fields
    }
    None => {
      let fields : Array[Bytes] = []
      let mut index = 0
      while index < line.length() {
        while index < line.length() &&
              (line[index] == b' ' || line[index] == b'\t') {
          index += 1
        }
        let start = index
        while index < line.length() &&
              line[index] != b' ' &&
              line[index] != b'\t' {
          index += 1
        }
        if start < index {
          fields.push(line[start:index].to_owned())
        }
      }
      fields
    }
  }
}

///|
fn key_of(fields : Array[Bytes], field : Int) -> Bytes {
  if field - 1 < fields.length() {
    fields[field - 1]
  } else {
    b""
  }
}

///|
fn rest_of(fields : Array[Bytes], field : Int) -> Array[Bytes] {
  let rest : Array[Bytes] = []
  for index, value in fields {
    if index != field - 1 {
      rest.push(value)
    }
  }
  rest
}

///|
fn bytes_equal(left : Bytes, right : Bytes) -> Bool {
  left[:].equal(right[:])
}

///|
fn compare_bytes(left : Bytes, right : Bytes) -> Int {
  left[:].lexical_compare(right[:])
}

///|
fn append_bytes(output : Array[Byte], value : Bytes) -> Unit {
  for byte in value {
    output.push(byte)
  }
}

///|
async fn write_joined(
  key : Bytes,
  left : Array[Bytes],
  right : Array[Bytes],
  separator : Byte,
) -> Unit {
  let output : Array[Byte] = []
  append_bytes(output, key)
  for value in left {
    output.push(separator)
    append_bytes(output, value)
  }
  for value in right {
    output.push(separator)
    append_bytes(output, value)
  }
  output.push(b'\n')
  @stdio.stdout.write(Bytes::from_array(output))
}

///|
async fn merge_readers(
  reader1 : &@io.Reader,
  reader2 : &@io.Reader,
  field1 : Int,
  field2 : Int,
  separator : Byte?,
) -> Unit {
  let scanner1 = @stream.LineScanner::new(reader1)
  let scanner2 = @stream.LineScanner::new(reader2)
  let mut fields1 = match scanner1.next() {
    Some(line) => Some(split_fields(line.data, separator))
    None => None
  }
  let mut fields2 = match scanner2.next() {
    Some(line) => Some(split_fields(line.data, separator))
    None => None
  }
  let out_separator = separator.unwrap_or(b' ')
  while fields1 is Some(left) && fields2 is Some(right) {
    let key1 = key_of(left, field1)
    let key2 = key_of(right, field2)
    let order = compare_bytes(key1, key2)
    if order < 0 {
      fields1 = match scanner1.next() {
        Some(line) => Some(split_fields(line.data, separator))
        None => None
      }
    } else if order > 0 {
      fields2 = match scanner2.next() {
        Some(line) => Some(split_fields(line.data, separator))
        None => None
      }
    } else {
      let left_run : Array[Array[Bytes]] = [left]
      let right_run : Array[Array[Bytes]] = [right]
      fields1 = None
      while scanner1.next() is Some(line) {
        let next = split_fields(line.data, separator)
        if bytes_equal(key_of(next, field1), key1) {
          left_run.push(next)
        } else {
          fields1 = Some(next)
          break
        }
      }
      fields2 = None
      while scanner2.next() is Some(line) {
        let next = split_fields(line.data, separator)
        if bytes_equal(key_of(next, field2), key2) {
          right_run.push(next)
        } else {
          fields2 = Some(next)
          break
        }
      }
      for left_fields in left_run {
        for right_fields in right_run {
          write_joined(
            key1,
            rest_of(left_fields, field1),
            rest_of(right_fields, field2),
            out_separator,
          )
        }
      }
    }
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.option("field1", short='1'),
    @cli.option("field2", short='2'),
    @cli.option("separator", short='t'),
    @cli.flag("help", short='h'),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("join: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  let field1 = match parsed.last_value("field1") {
    Some(value) => {
      let number = @string.parse_int(value) catch {
        _ => {
          @stdio.stderr.write("join: invalid field number: '\{value}'\n")
          @sys.exit(2)
          return
        }
      }
      if number < 1 {
        @stdio.stderr.write("join: invalid field number: '\{value}'\n")
        @sys.exit(2)
        return
      }
      number
    }
    None => 1
  }
  let field2 = match parsed.last_value("field2") {
    Some(value) => {
      let number = @string.parse_int(value) catch {
        _ => {
          @stdio.stderr.write("join: invalid field number: '\{value}'\n")
          @sys.exit(2)
          return
        }
      }
      if number < 1 {
        @stdio.stderr.write("join: invalid field number: '\{value}'\n")
        @sys.exit(2)
        return
      }
      number
    }
    None => 1
  }
  let separator = match parsed.last_value("separator") {
    Some(value) => {
      let encoded = @utf8.encode(value)
      if encoded.length() != 1 {
        @stdio.stderr.write(
          "join: the separator must be a single byte in C locale\n",
        )
        @sys.exit(2)
        return
      }
      Some(encoded[0])
    }
    None => None
  }
  let files = parsed.operands
  if files.length() != 2 {
    @stdio.stderr.write(
      "join: expected exactly two files\n\n" + help_message() + "\n",
    )
    @sys.exit(2)
    return
  }
  if files[0] == "-" && files[1] == "-" {
    @stdio.stderr.write("join: both inputs cannot be standard input\n")
    @sys.exit(2)
    return
  }
  try {
    if files[0] == "-" {
      let file2 = @fs.open(files[1], mode=ReadOnly)
      defer file2.close()
      merge_readers(@stdio.stdin, file2, field1, field2, separator)
    } else if files[1] == "-" {
      let file1 = @fs.open(files[0], mode=ReadOnly)
      defer file1.close()
      merge_readers(file1, @stdio.stdin, field1, field2, separator)
    } else {
      let file1 = @fs.open(files[0], mode=ReadOnly)
      defer file1.close()
      let file2 = @fs.open(files[1], mode=ReadOnly)
      defer file2.close()
      merge_readers(file1, file2, field1, field2, separator)
    }
  } catch {
    err => {
      @stdio.stderr.write("join: \{err}\n")
      @sys.exit(1)
      return
    }
  }
}
