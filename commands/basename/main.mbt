///|
fn chars_string(chars : Array[Char], start : Int, end : Int) -> String {
  let out = StringBuilder()
  for i in start..<end {
    out.write_char(chars[i])
  }
  out.to_string()
}

///|
fn base_name(path : String) -> String {
  if path is "" {
    return ""
  }
  let chars : Array[Char] = path.iter().collect()
  let mut end = chars.length()
  while end > 1 && chars[end - 1] == '/' {
    end -= 1
  }
  if end == 1 && chars[0] == '/' {
    return "/"
  }
  let mut start = end
  while start > 0 && chars[start - 1] != '/' {
    start -= 1
  }
  chars_string(chars, start, end)
}

///|
fn strip_suffix(name : String, suffix : String) -> String {
  if suffix != "" && name != suffix && name.has_suffix(suffix) {
    name[0:name.length() - suffix.length()].to_owned()
  } else {
    name
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("multiple", short='a'),
    @cli.option("suffix", short='s'),
    @cli.flag("zero", short='z'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("basename: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  let multiple = parsed.contains("multiple") || parsed.contains("suffix")
  let zero = parsed.contains("zero")
  let mut suffix = parsed.last_value("suffix")
  let operands = parsed.operands
  if parsed.contains("help") {
    @stdio.stdout.write("Usage: basename [-a] [-s SUFFIX] [-z] NAME [SUFFIX]\n")
    return
  }
  if operands.is_empty() || (!multiple && operands.length() > 2) {
    @stdio.stderr.write("basename: missing or extra operand\n")
    @sys.exit(1)
    return
  }
  if !multiple && operands.length() == 2 {
    suffix = Some(operands[1])
  }
  let count = if multiple { operands.length() } else { 1 }
  let separator = if zero { "\u0000" } else { "\n" }
  for index in 0..<count {
    let name = base_name(operands[index])
    let output = match suffix {
      Some(value) => strip_suffix(name, value)
      None => name
    }
    @stdio.stdout.write(output + separator)
  }
}
