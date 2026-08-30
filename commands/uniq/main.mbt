///|
fn pad_left(text : String, width : Int) -> String {
  let sb = StringBuilder()
  for _ in 0..<(width - text.length()) {
    sb.write_char(' ')
  }
  sb.write_string(text)
  sb.to_string()
}

///|
fn equal_line(left : Bytes, right : Bytes, ignore_case : Bool) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index = 0; index < left.length(); index = index + 1 {
    let l = left[index].to_int()
    let r = right[index].to_int()
    let l = if ignore_case && l >= 0x41 && l <= 0x5A { l + 0x20 } else { l }
    let r = if ignore_case && r >= 0x41 && r <= 0x5A { r + 0x20 } else { r }
    if l != r {
      return false
    }
  }
  true
}

///|
async fn write_group(
  line : Bytes,
  count : Int,
  show_count : Bool,
  only_repeated : Bool,
  only_unique : Bool,
) -> Unit {
  let selected = if only_repeated && only_unique {
    false
  } else if only_repeated {
    count > 1
  } else if only_unique {
    count == 1
  } else {
    true
  }
  if selected {
    if show_count {
      @stdio.stdout.write(pad_left(count.to_string(), 7) + " ")
    }
    @stdio.stdout.write(line)
    @stdio.stdout.write("\n")
  }
}

///|
async fn process_reader(
  reader : &@io.Reader,
  show_count : Bool,
  only_repeated : Bool,
  only_unique : Bool,
  ignore_case : Bool,
) -> Unit {
  let scanner = @stream.LineScanner::new(reader)
  let mut previous : Bytes? = None
  let mut count = 0
  while scanner.next() is Some(line) {
    match previous {
      Some(value) if equal_line(value, line.data, ignore_case) => count += 1
      Some(value) => {
        write_group(value, count, show_count, only_repeated, only_unique)
        previous = Some(line.data)
        count = 1
      }
      None => {
        previous = Some(line.data)
        count = 1
      }
    }
  }
  if previous is Some(value) {
    write_group(value, count, show_count, only_repeated, only_unique)
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("count", short='c'),
    @cli.flag("repeated", short='d'),
    @cli.flag("unique", short='u'),
    @cli.flag("ignore-case", short='i'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("uniq: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write("Usage: uniq [-cdui] [FILE]\n")
    return
  }
  if parsed.operands.length() > 1 {
    @stdio.stderr.write("uniq: extra operand: '\{parsed.operands[1]}'\n")
    @sys.exit(2)
    return
  }
  let show_count = parsed.contains("count")
  let only_repeated = parsed.contains("repeated")
  let only_unique = parsed.contains("unique")
  let ignore_case = parsed.contains("ignore-case")
  let inputs = parsed.operands
  let path = if inputs.is_empty() { "-" } else { inputs[0] }
  try {
    if path == "-" {
      process_reader(
        @stdio.stdin, show_count, only_repeated, only_unique, ignore_case,
      )
    } else {
      let file = @fs.open(path, mode=ReadOnly)
      defer file.close()
      process_reader(file, show_count, only_repeated, only_unique, ignore_case)
    }
  } catch {
    err => {
      @stdio.stderr.write("uniq: \{err}\n")
      @sys.exit(1)
      return
    }
  }
}
