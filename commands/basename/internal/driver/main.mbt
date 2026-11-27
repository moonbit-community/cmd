///|
fn chars_string(chars : Array[Char], start : Int32, end : Int32) -> String {
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
pub async fn run_main() -> Unit {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.text.write("basename \{MODULE_VERSION}\n")
    return
  }
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, option_specs()) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("basename: \{message}: '\{option}'\n")
      @env.exit(1)
      return
    }
  }
  let multiple = parsed.contains("multiple") || parsed.contains("suffix")
  let zero = parsed.contains("zero")
  let mut suffix = parsed.last_value("suffix")
  let operands = parsed.operands
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if operands.is_empty() || (!multiple && operands.length() > 2) {
    @stdio.stderr.text.write("basename: missing or extra operand\n")
    @env.exit(1)
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
    @stdio.stdout.text.write(output + separator)
  }
}
