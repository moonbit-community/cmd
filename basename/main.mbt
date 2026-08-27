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
  let mut multiple = false
  let mut zero = false
  let mut suffix : String? = None
  let operands : Array[String] = []
  let mut options = true
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if options && arg == "--" {
      options = false
    } else if options && (arg == "-a" || arg == "--multiple") {
      multiple = true
    } else if options && (arg == "-z" || arg == "--zero") {
      zero = true
    } else if options && (arg == "-s" || arg == "--suffix") {
      if i + 1 >= args.length() {
        @stdio.stderr.write("basename: missing suffix operand\n")
        @sys.exit(1)
        return
      }
      i += 1
      suffix = Some(args[i])
      multiple = true
    } else if options && arg.has_prefix("--suffix=") {
      suffix = Some(arg[9:].to_owned())
      multiple = true
    } else if options && arg == "--help" {
      @stdio.stdout.write(
        "Usage: basename [-a] [-s SUFFIX] [-z] NAME [SUFFIX]\n",
      )
      return
    } else if options && arg.has_prefix("-") && arg != "-" {
      let mut valid = true
      for flag in arg[1:] {
        match flag {
          'a' => multiple = true
          'z' => zero = true
          _ => valid = false
        }
      }
      if !valid {
        @stdio.stderr.write("basename: invalid option: '\{arg}'\n")
        @sys.exit(1)
        return
      }
    } else {
      operands.push(arg)
    }
    i += 1
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
