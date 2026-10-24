///|
priv suberror JoinError {
  JoinError(String)
  JoinOrderError
}

///|
fn help_message() -> String {
  let message =
    #|Usage: join [options] FILE1 FILE2
    #|  -h, --help      display this help and exit
    #|      --version   display version and exit
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
    #|  -e STRING    Replace missing or empty fields with STRING.
    #|  -o LIST      Select output fields (for example 0,1.2,2.2), or auto.
    #|  -i, --ignore-case  Compare join fields without ASCII case distinctions.
    #|      --header  Print the first lines as headers without matching keys.
    #|      --check-order  Diagnose unsorted input.
    #|      --nocheck-order  Do not diagnose unsorted input.
    #|  -z           End records with NUL instead of newline.
    #|
    #|Use '-' as a file name to read stdin.
  message
}

///|
priv struct JoinRow {
  fields : Array[Bytes]
}

///|
priv struct JoinOrder {
  mut previous_key : Bytes?
  mut line_number : Int64
  mut warned : Bool
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
fn key_of(fields : Array[Bytes], field : Int32) -> Bytes {
  if field - 1 < fields.length() {
    fields[field - 1]
  } else {
    b""
  }
}

///|
fn rest_of(
  fields : Array[Bytes],
  field : Int32,
  width : Int32,
  empty : String,
) -> Array[Bytes] {
  let rest : Array[Bytes] = []
  for index = 0; index < width; index = index + 1 {
    if index != field - 1 {
      rest.push(field_at(fields, index, empty))
    }
  }
  rest
}

///|
fn compare_bytes(left : Bytes, right : Bytes, ignore_case : Bool) -> Int32 {
  if !ignore_case {
    return left[:].lexical_compare(right[:])
  }
  let length = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  for index = 0; index < length; index = index + 1 {
    let a = left[index]
    let b = right[index]
    let a = if a >= b'A' && a <= b'Z' { a.to_int() + 32 } else { a.to_int() }
    let b = if b >= b'A' && b <= b'Z' { b.to_int() + 32 } else { b.to_int() }
    if a != b {
      return a - b
    }
  }
  left.length() - right.length()
}

///|
fn append_bytes(output : Array[Byte], value : Bytes) -> Unit {
  for byte in value {
    output.push(byte)
  }
}

///|
fn field_at(fields : Array[Bytes], index : Int32, empty : String) -> Bytes {
  if index < fields.length() && fields[index].length() > 0 {
    fields[index]
  } else {
    @utf8.encode(empty)
  }
}

///|
fn parse_output_field(value : String) -> (Int32, Int32)? {
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
) -> Array[Int32] raise {
  let values : Array[Int32] = []
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
  field1 : Int32,
  field2 : Int32,
  separator : Byte,
  empty : String,
  format_fields : Array[(Int32, Int32)],
  auto_counts : (Int32, Int32)?,
  record_delimiter : Byte,
) -> Unit {
  let output : Array[Byte] = []
  let key = match (left, right) {
    (Some(row), _) => field_at(row.fields, field1 - 1, empty)
    (_, Some(row)) => field_at(row.fields, field2 - 1, empty)
    _ => b""
  }
  let rendered : Array[Bytes] = []
  if format_fields.is_empty() {
    rendered.push(key)
    let fields1 = match left {
      Some(row) => row.fields
      None => []
    }
    let fields2 = match right {
      Some(row) => row.fields
      None => []
    }
    let (width1, width2) = auto_counts.unwrap_or(
      (fields1.length(), fields2.length()),
    )
    for value in rest_of(fields1, field1, width1, empty) {
      rendered.push(value)
    }
    for value in rest_of(fields2, field2, width2, empty) {
      rendered.push(value)
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
  state : JoinOrder,
  field : Int32,
  separator : Byte?,
  name : String,
  order_mode : Int32,
  ignore_case : Bool,
  unpairable : Ref[Bool],
) -> JoinRow? {
  match scanner.next() {
    Some(line) => {
      let row : JoinRow = { fields: split_fields(line.data, separator), }
      let key = key_of(row.fields, field)
      state.line_number += 1
      if !state.warned &&
        (order_mode > 0 || (order_mode == 0 && unpairable.val)) {
        match state.previous_key {
          Some(previous) if compare_bytes(previous, key, ignore_case) > 0 => {
            @stdio.stderr.write(
              "join: \{name}:\{state.line_number}: is not sorted: ",
            )
            let mut end = line.data.length()
            if end > 0 && line.data[end - 1] == b'\n' {
              end -= 1
            }
            for index = 0; index < end; index = index + 1 {
              if line.data[index] == b'\x00' {
                end = index
                break
              }
            }
            @stdio.stderr.write(line.data[:end].to_owned())
            @stdio.stderr.write("\n")
            if order_mode > 0 {
              raise JoinOrderError
            }
            state.warned = true
          }
          _ => ()
        }
      }
      state.previous_key = Some(key)
      Some(row)
    }
    None => None
  }
}

///|
async fn merge_readers(
  reader1 : &@io.Reader,
  reader2 : &@io.Reader,
  field1 : Int32,
  field2 : Int32,
  separator : Byte?,
  all : Array[Int32],
  only : Array[Int32],
  empty : String,
  output_fields : Array[(Int32, Int32)],
  record_delimiter : Byte,
  order_mode : Int32,
  ignore_case : Bool,
  header : Bool,
  auto_format : Bool,
  name1 : String,
  name2 : String,
) -> Unit {
  let scanner1 = @stream.LineScanner::new(reader1, delimiter=record_delimiter)
  let scanner2 = @stream.LineScanner::new(reader2, delimiter=record_delimiter)
  let state1 : JoinOrder = {
    previous_key: None,
    line_number: 0,
    warned: false,
  }
  let state2 : JoinOrder = {
    previous_key: None,
    line_number: 0,
    warned: false,
  }
  let unpairable = Ref(false)
  let mut row1 = next_ordered_row(
    scanner1, state1, field1, separator, name1, order_mode, ignore_case, unpairable,
  )
  let mut row2 = next_ordered_row(
    scanner2, state2, field2, separator, name2, order_mode, ignore_case, unpairable,
  )
  let out_separator = separator.unwrap_or(b' ')
  let auto_counts = if auto_format {
    let width1 = match row1 {
      Some(row) => row.fields.length()
      None => 0
    }
    let width2 = match row2 {
      Some(row) => row.fields.length()
      None => 0
    }
    Some((width1, width2))
  } else {
    None
  }
  if header && (row1 is Some(_) || row2 is Some(_)) {
    write_joined(
      row1, row2, field1, field2, out_separator, empty, output_fields, auto_counts,
      record_delimiter,
    )
    state1.previous_key = None
    state2.previous_key = None
    if row1 is Some(_) {
      row1 = next_ordered_row(
        scanner1, state1, field1, separator, name1, order_mode, ignore_case, unpairable,
      )
    }
    if row2 is Some(_) {
      row2 = next_ordered_row(
        scanner2, state2, field2, separator, name2, order_mode, ignore_case, unpairable,
      )
    }
  }
  while row1 is Some(left) && row2 is Some(right) {
    let key1 = key_of(left.fields, field1)
    let key2 = key_of(right.fields, field2)
    let order = compare_bytes(key1, key2, ignore_case)
    if order < 0 {
      if all.contains(1) || only.contains(1) {
        write_joined(
          Some(left),
          None,
          field1,
          field2,
          out_separator,
          empty,
          output_fields,
          auto_counts,
          record_delimiter,
        )
      }
      row1 = next_ordered_row(
        scanner1, state1, field1, separator, name1, order_mode, ignore_case, unpairable,
      )
      unpairable.val = true
    } else if order > 0 {
      if all.contains(2) || only.contains(2) {
        write_joined(
          None,
          Some(right),
          field1,
          field2,
          out_separator,
          empty,
          output_fields,
          auto_counts,
          record_delimiter,
        )
      }
      row2 = next_ordered_row(
        scanner2, state2, field2, separator, name2, order_mode, ignore_case, unpairable,
      )
      unpairable.val = true
    } else {
      let left_run : Array[JoinRow] = [left]
      let right_run : Array[JoinRow] = [right]
      row1 = None
      while next_ordered_row(
              scanner1, state1, field1, separator, name1, order_mode, ignore_case,
              unpairable,
            )
            is Some(next) {
        if compare_bytes(key_of(next.fields, field1), key1, ignore_case) == 0 {
          left_run.push(next)
        } else {
          row1 = Some(next)
          break
        }
      }
      row2 = None
      while next_ordered_row(
              scanner2, state2, field2, separator, name2, order_mode, ignore_case,
              unpairable,
            )
            is Some(next) {
        if compare_bytes(key_of(next.fields, field2), key2, ignore_case) == 0 {
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
              auto_counts,
              record_delimiter,
            )
          }
        }
      }
    }
  }
  while row1 is Some(left) {
    if all.contains(1) || only.contains(1) {
      write_joined(
        Some(left),
        None,
        field1,
        field2,
        out_separator,
        empty,
        output_fields,
        auto_counts,
        record_delimiter,
      )
    }
    row1 = next_ordered_row(
      scanner1, state1, field1, separator, name1, order_mode, ignore_case, unpairable,
    )
  }
  while row2 is Some(right) {
    if all.contains(2) || only.contains(2) {
      write_joined(
        None,
        Some(right),
        field1,
        field2,
        out_separator,
        empty,
        output_fields,
        auto_counts,
        record_delimiter,
      )
    }
    row2 = next_ordered_row(
      scanner2, state2, field2, separator, name2, order_mode, ignore_case, unpairable,
    )
  }
  if state1.warned || state2.warned {
    raise JoinError("input is not in sorted order")
  }
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("join 0.2.2\n")
    return
  }
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.option("field1", short='1'),
    @cli.option("field2", short='2'),
    @cli.option("separator", short='t'),
    @cli.option("after", short='a'),
    @cli.option("only", short='v'),
    @cli.option("empty", short='e'),
    @cli.option("output", short='o'),
    @cli.flag("ignore-case", short='i'),
    @cli.flag("header"),
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
  let order_mode = match
    parsed.last_occurrence(["check-order", "nocheck-order"]) {
    Some("nocheck-order") => -1
    Some(_) => 1
    None => 0
  }
  let ignore_case = parsed.contains("ignore-case")
  let header = parsed.contains("header")
  let mut auto_format = false
  let output_fields : Array[(Int32, Int32)] = []
  for value in parsed.values("output") {
    if value == "auto" {
      auto_format = true
      continue
    }
    for item in value.split(",") {
      match parse_output_field(item.to_owned()) {
        Some(field) => output_fields.push(field)
        None => {
          let item = item.to_owned()
          if item.has_prefix("1.") || item.has_prefix("2.") {
            @stdio.stderr.write("join: invalid field number: '\{item[2:]}'\n")
          } else if item.has_prefix("0") ||
            item.has_prefix("1") ||
            item.has_prefix("2") {
            @stdio.stderr.write("join: invalid field specifier: '\{item}'\n")
          } else {
            @stdio.stderr.write(
              "join: invalid file number in field spec: '\{item}'\n",
            )
          }
          @sys.exit(1)
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
        @stdio.stdin,
        file2,
        field1,
        field2,
        separator,
        all,
        only,
        empty,
        output_fields,
        record_delimiter,
        order_mode,
        ignore_case,
        header,
        auto_format,
        files[0],
        files[1],
      )
    } else if files[1] == "-" {
      let file1 = @fs.open(files[0], mode=ReadOnly)
      defer file1.close()
      merge_readers(
        file1,
        @stdio.stdin,
        field1,
        field2,
        separator,
        all,
        only,
        empty,
        output_fields,
        record_delimiter,
        order_mode,
        ignore_case,
        header,
        auto_format,
        files[0],
        files[1],
      )
    } else {
      let file1 = @fs.open(files[0], mode=ReadOnly)
      defer file1.close()
      let file2 = @fs.open(files[1], mode=ReadOnly)
      defer file2.close()
      merge_readers(
        file1,
        file2,
        field1,
        field2,
        separator,
        all,
        only,
        empty,
        output_fields,
        record_delimiter,
        order_mode,
        ignore_case,
        header,
        auto_format,
        files[0],
        files[1],
      )
    }
  } catch {
    JoinOrderError => {
      @sys.exit(1)
      return
    }
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
