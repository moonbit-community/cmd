///|
fn chars_string(chars : Array[Char], end : Int) -> String {
  let out = StringBuilder()
  for i in 0..<end {
    out.write_char(chars[i])
  }
  out.to_string()
}

///|
fn dir_name(path : String) -> String {
  if path is "" {
    return "."
  }
  let chars : Array[Char] = path.iter().collect()
  let mut end = chars.length()
  while end > 1 && chars[end - 1] == '/' {
    end -= 1
  }
  if end == 1 && chars[0] == '/' {
    return "/"
  }
  while end > 0 && chars[end - 1] != '/' {
    end -= 1
  }
  if end == 0 {
    return "."
  }
  while end > 1 && chars[end - 1] == '/' {
    end -= 1
  }
  chars_string(chars, end)
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("zero", short='z'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("dirname: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write("Usage: dirname [-z] NAME...\n")
    return
  }
  let operands = parsed.operands
  let zero = parsed.contains("zero")
  if operands.is_empty() {
    @stdio.stderr.write("dirname: missing operand\n")
    @sys.exit(1)
    return
  }
  let separator = if zero { "\u0000" } else { "\n" }
  for path in operands {
    @stdio.stdout.write(dir_name(path) + separator)
  }
}
