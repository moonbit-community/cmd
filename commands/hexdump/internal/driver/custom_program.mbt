///|
fn builtin_mode(name : String) -> Bool {
  [
    "one-byte-octal", "one-byte-char", "canonical", "two-bytes-decimal", "two-bytes-octal",
    "two-bytes-hex", "one-byte-hex",
  ].contains(name)
}

///|
fn normalized_args(args : ArrayView[String]) -> Array[String] {
  let result : Array[String] = []
  let mut options = true
  let mut value_next = false
  for arg in args {
    if value_next {
      result.push(arg)
      value_next = false
      continue
    }
    if arg == "--" {
      options = false
      result.push(arg)
      continue
    }
    if !options {
      result.push(arg)
      continue
    }
    if arg == "--color" {
      result.push("--color=auto")
      continue
    }
    let mut rewritten = false
    if arg.has_prefix("-") && !arg.has_prefix("--") {
      for index in 1..<arg.length() {
        if arg[index] is ('e' | 'f' | 'n' | 's') {
          value_next = index + 1 == arg.length()
          break
        }
        if arg[index] == 'L' {
          if index > 1 {
            result.push(arg[:index].to_owned())
          }
          let value = if index + 1 == arg.length() {
            "auto"
          } else {
            arg[index + 1:].to_owned()
          }
          result.push("--color=" + value)
          rewritten = true
          break
        }
      }
    }
    if !rewritten {
      result.push(arg)
    }
    if ["--format", "--format-file", "--length", "--skip"].contains(arg) {
      value_next = true
    }
  }
  result
}

///|
async fn program(parsed : @cli.ParsedArgs) -> @format.Program {
  let entries : Array[@format.Entry] = []
  let mut colors = false
  for value in parsed.values("color") {
    match value {
      "always" => colors = true
      "auto" | "never" => colors = false
      _ => raise HexdumpError("unsupported color mode: '\{value}'")
    }
  }
  let mut format_index = 0
  let mut file_index = 0
  for name in parsed.order {
    if builtin_mode(name) {
      entries.push(Builtin(name))
    } else if name == "format" {
      let source = parsed.values("format")[format_index]
      entries.push(
        Custom(@format.compile_format(@utf8.encode(source)[:], colors)),
      )
      format_index += 1
    } else if name == "format-file" {
      let file = parsed.values("format-file")[file_index]
      let bytes = @fs.read_file(file).binary()
      for format in @format.compile_lines(bytes, colors) {
        entries.push(Custom(format))
      }
      file_index += 1
    }
  }
  if entries.is_empty() {
    entries.push(Builtin("default"))
  }
  @format.finish_program(entries)
}
