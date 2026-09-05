///|
priv suberror JoinError {
  JoinError(String)
}

///|
fn help_message() -> String {
  let message =
    #|Usage: join [options] FILE1 FILE2
    #|
    #|Join lines of two files sorted on their join fields.
    #|
    #|Options:
    #|  -1 FIELD    Join on this field of FILE1 (default 1).
    #|  -2 FIELD    Join on this field of FILE2 (default 1).
    #|  -t CHAR     Use CHAR as the field separator instead of runs of
    #|              blanks; the output separator becomes CHAR as well.
    #|  -a FILENO    Also print unpairable lines from FILENO (1 or 2).
    #|  -v FILENO    Print only unpairable lines from FILENO.
    #|  -e STRING    Replace missing fields with STRING.
    #|  -o LIST      Select output fields (for example 0,1.2,2.2).
    #|      --check-order  Diagnose unsorted input.
    #|      --nocheck-order  Do not diagnose unsorted input.
    #|  -z           End records with NUL instead of newline.
    #|  -h, --help  Show this help message.
    #|
    #|Use '-' as a file name to read stdin.
  message
}

///|
priv struct JoinRow {
  fields : Array[Bytes]
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
fn field_at(fields : Array[Bytes], index : Int, empty : String) -> Bytes {
  if index < fields.length() {
    fields[index]
  } else {
    @utf8.encode(empty)
  }
}

///|
fn parse_output_field(value : String) -> (Int, Int)? {
  if value == "0" {
    return Some((0, 0))
  }
  match value.split_once(".") {
    Some((file, field)) => {
      let file_number = @string.parse_int(file) catch { _ => return None }
      let field_number = @string.parse_int(field) catch { _ => return None }
      if (file_number == 1 || file_number == 2) && field_number > 0 {
        Some((file_number, field_number))
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn parse_file_numbers(
  parsed : @cli.ParsedArgs,
  name : String,
) -> Array[Int] raise {
  let values : Array[Int] = []
  for value in parsed.values(name) {
    let number = @string.parse_int(value) catch {
      _ => raise Failure("join: invalid file number: '\{value}'")
    }
    if number != 1 && number != 2 {
      raise Failure("join: invalid file number: '\{value}'")
    }
    values.push(number)
  }
  values
}

///|
async fn write_joined(
  left : JoinRow?,
  right : JoinRow?,
  field1 : Int,
  field2 : Int,
  separator : Byte,
  empty : String,
  format_fields : Array[(Int, Int)],
  record_delimiter : Byte,
) -> Unit {
  let output : Array[Byte] = []
  let key = match (left, right) {
    (Some(row), _) => key_of(row.fields, field1)
    (_, Some(row)) => key_of(row.fields, field2)
    _ => b""
  }
  let rendered : Array[Bytes] = []
  if format_fields.is_empty() {
    rendered.push(key)
    match left {
      Some(row) =>
        for value in rest_of(row.fields, field1) {
          rendered.push(value)
        }
      None => ()
    }
    match right {
      Some(row) =>
        for value in rest_of(row.fields, field2) {
          rendered.push(value)
        }
      None => ()
    }
  } else {
    for item in format_fields {
      let (file, field) = item
      if file == 0 {
        rendered.push(key)
      } else if file == 1 {
        let fields = match left {
          Some(row) => row.fields
          None => []
        }
        rendered.push(field_at(fields, field - 1, empty))
      } else {
        let fields = match right {
          Some(row) => row.fields
          None => []
        }
        rendered.push(field_at(fields, field - 1, empty))
      }
    }
  }
  for index, value in rendered {
    if index > 0 {
      output.push(separator)
    }
    append_bytes(output, value)
  }
  output.push(record_delimiter)
  @stdio.stdout.write(Bytes::from_array(output))
}

///|
async fn next_ordered_row(
  scanner : @stream.LineScanner,
  previous_key : Ref[Bytes?],
  field : Int,
  separator : Byte?,
  name : String,
  order_mode : Int,
  unordered : Ref[Bool],
) -> JoinRow? {
  match scanner.next() {
    Some(line) => {
      let row : JoinRow = { fields: split_fields(line.data, separator), }
      let key = key_of(row.fields, field)
      match previous_key.val {
        Some(previous) if compare_bytes(previous, key) > 0 => {
          unordered.val = true
          if order_mode > 0 {
            raise JoinError("\{name} is not in sorted order")
          }
        }
        _ => ()
      }
      previous_key.val = Some(key)
      Some(row)
    }
    None => None
  }
}

///|
async fn merge_readers(
  reader1 : &@io.Reader,
  reader2 : &@io.Reader,
  field1 : Int,
  field2 : Int,
  separator : Byte?,
  all : Array[Int],
  only : Array[Int],
  empty : String,
  output_fields : Array[(Int, Int)],
  record_delimiter : Byte,
  order_mode : Int,
) -> Unit {
  let scanner1 = @stream.LineScanner::new(reader1, delimiter=record_delimiter)
  let scanner2 = @stream.LineScanner::new(reader2, delimiter=record_delimiter)
  let previous_key1 : Ref[Bytes?] = Ref(None)
  let previous_key2 : Ref[Bytes?] = Ref(None)
  let unordered1 = Ref(false)
  let unordered2 = Ref(false)
  let mut row1 = next_ordered_row(
    scanner1, previous_key1, field1, separator, "file 1", order_mode, unordered1,
  )
  let mut row2 = next_ordered_row(
    scanner2, previous_key2, field2, separator, "file 2", order_mode, unordered2,
  )
  let out_separator = separator.unwrap_or(b' ')
  fn mark_unpairable(
    order_mode : Int,
    unordered1 : Ref[Bool],
    unordered2 : Ref[Bool],
  ) -> Unit raise JoinError {
    if order_mode == 0 && (unordered1.val || unordered2.val) {
      raise JoinError("input is not in sorted order")
    }
  }
  while row1 is Some(left) && row2 is Some(right) {
    let key1 = key_of(left.fields, field1)
    let key2 = key_of(right.fields, field2)
    let order = compare_bytes(key1, key2)
    if order < 0 {
      mark_unpairable(order_mode, unordered1, unordered2)
      if (all.contains(1) || only.contains(1)) &&
        (only.is_empty() || only.contains(1)) {
        write_joined(
          Some(left),
          None,
          field1,
          field2,
          out_separator,
          empty,
          output_fields,
          record_delimiter,
        )
      }
      row1 = next_ordered_row(
        scanner1, previous_key1, field1, separator, "file 1", order_mode, unordered1,
      )
    } else if order > 0 {
      mark_unpairable(order_mode, unordered1, unordered2)
      if (all.contains(2) || only.contains(2)) &&
        (only.is_empty() || only.contains(2)) {
        write_joined(
          None,
          Some(right),
          field1,
          field2,
          out_separator,
          empty,
          output_fields,
          record_delimiter,
        )
      }
      row2 = next_ordered_row(
        scanner2, previous_key2, field2, separator, "file 2", order_mode, unordered2,
      )
    } else {
      let left_run : Array[JoinRow] = [left]
      let right_run : Array[JoinRow] = [right]
      row1 = None
      while next_ordered_row(
              scanner1, previous_key1, field1, separator, "file 1", order_mode, unordered1,
            )
            is Some(next) {
        if bytes_equal(key_of(next.fields, field1), key1) {
          left_run.push(next)
        } else {
          row1 = Some(next)
          break
        }
      }
      row2 = None
      while next_ordered_row(
              scanner2, previous_key2, field2, separator, "file 2", order_mode, unordered2,
            )
            is Some(next) {
        if bytes_equal(key_of(next.fields, field2), key2) {
          right_run.push(next)
        } else {
          row2 = Some(next)
          break
        }
      }
      if only.is_empty() {
        for left_item in left_run {
          for right_item in right_run {
            write_joined(
              Some(left_item),
              Some(right_item),
              field1,
              field2,
              out_separator,
              empty,
              output_fields,
              record_delimiter,
            )
          }
        }
      }
    }
  }
  while row1 is Some(left) {
    mark_unpairable(order_mode, unordered1, unordered2)
    if all.contains(1) || only.contains(1) {
      write_joined(
        Some(left),
        None,
        field1,
        field2,
        out_separator,
        empty,
        output_fields,
        record_delimiter,
      )
    }
    row1 = next_ordered_row(
      scanner1, previous_key1, field1, separator, "file 1", order_mode, unordered1,
    )
  }
  while row2 is Some(right) {
    mark_unpairable(order_mode, unordered1, unordered2)
    if all.contains(2) || only.contains(2) {
      write_joined(
        None,
        Some(right),
        field1,
        field2,
        out_separator,
        empty,
        output_fields,
        record_delimiter,
      )
    }
    row2 = next_ordered_row(
      scanner2, previous_key2, field2, separator, "file 2", order_mode, unordered2,
    )
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.option("field1", short='1'),
    @cli.option("field2", short='2'),
    @cli.option("separator", short='t'),
    @cli.option("after", short='a'),
    @cli.option("only", short='v'),
    @cli.option("empty", short='e'),
    @cli.option("output", short='o'),
    @cli.flag("help", short='h'),
    @cli.flag("check-order"),
    @cli.flag("nocheck-order"),
    @cli.flag("zero-terminated", short='z'),
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
  let all = parse_file_numbers(parsed, "after") catch {
    err => {
      @stdio.stderr.write("\{err}\n")
      @sys.exit(2)
      return
    }
  }
  let only = parse_file_numbers(parsed, "only") catch {
    err => {
      @stdio.stderr.write("\{err}\n")
      @sys.exit(2)
      return
    }
  }
  let empty = parsed.last_value("empty").unwrap_or("")
  let order_mode = if parsed.contains("nocheck-order") {
    -1
  } else if parsed.contains("check-order") {
    1
  } else {
    0
  }
  let output_fields : Array[(Int, Int)] = []
  for value in parsed.values("output") {
    for item in value.split(",") {
      match parse_output_field(item.to_owned()) {
        Some(field) => output_fields.push(field)
        None => {
          @stdio.stderr.write("join: invalid field list: '\{value}'\n")
          @sys.exit(2)
          return
        }
      }
    }
  }
  let files = parsed.operands
  let record_delimiter = if parsed.contains("zero-terminated") {
    b'\x00'
  } else {
    b'\n'
  }
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
      merge_readers(
        @stdio.stdin, file2, field1, field2, separator, all, only, empty, output_fields,
        record_delimiter, order_mode,
      )
    } else if files[1] == "-" {
      let file1 = @fs.open(files[0], mode=ReadOnly)
      defer file1.close()
      merge_readers(
        file1, @stdio.stdin, field1, field2, separator, all, only, empty, output_fields,
        record_delimiter, order_mode,
      )
    } else {
      let file1 = @fs.open(files[0], mode=ReadOnly)
      defer file1.close()
      let file2 = @fs.open(files[1], mode=ReadOnly)
      defer file2.close()
      merge_readers(
        file1, file2, field1, field2, separator, all, only, empty, output_fields,
        record_delimiter, order_mode,
      )
    }
  } catch {
    JoinError(message) => {
      @stdio.stderr.write("join: \{message}\n")
      @sys.exit(1)
      return
    }
    err => {
      @stdio.stderr.write("join: \{err}\n")
      @sys.exit(1)
      return
    }
  }
}
