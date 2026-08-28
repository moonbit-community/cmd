///|
fn uniq_command() -> @argparse.Command {
  Command(
    "uniq",
    about="Filter adjacent repeated lines.",
    flags=[
      FlagArg("count", short='c', about="Prefix lines with occurrence counts."),
      FlagArg("repeated", short='d', about="Only print lines that repeat."),
      FlagArg("unique", short='u', about="Only print lines that do not repeat."),
      FlagArg("ignore-case", short='i', about="Compare case-insensitively."),
    ],
    positionals=[
      PositionArg(
        "input",
        about="[file] ('-' or no file reads stdin)",
        num_args=ValueRange(lower=0, upper=1),
      ),
    ],
    disable_help_subcommand=true,
  )
}

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
  let command = uniq_command()
  let matches = command.parse(argv=args, env=Map([])) catch {
    err => {
      @stdio.stderr.write("\{err}\n")
      @sys.exit(2)
      return
    }
  }
  let show_count = matches.flags.get_or_default("count", false)
  let only_repeated = matches.flags.get_or_default("repeated", false)
  let only_unique = matches.flags.get_or_default("unique", false)
  let ignore_case = matches.flags.get_or_default("ignore-case", false)
  let inputs = matches.values.get("input").unwrap_or([])
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
