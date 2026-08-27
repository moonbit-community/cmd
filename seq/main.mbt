///|
fn parse_number(text : String) -> Double raise {
  if text.contains("_") {
    fail("invalid number")
  }
  let value = @string.parse_double(text)
  if value.is_nan() || value.is_inf() {
    fail("invalid number")
  }
  value
}

///|
fn zero_pad(text : String, width : Int) -> String {
  if text.length() >= width {
    return text
  }
  let zeros = "0".repeat(width - text.length())
  if text.has_prefix("-") {
    "-" + zeros + text[1:].to_owned()
  } else {
    zeros + text
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let operands : Array[String] = []
  let mut separator = "\n"
  let mut equal_width = false
  let mut options = true
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if options && arg == "--" {
      options = false
    } else if options && (arg == "-w" || arg == "--equal-width") {
      equal_width = true
    } else if options && (arg == "-s" || arg == "--separator") {
      if i + 1 >= args.length() {
        @stdio.stderr.write("seq: missing separator\n")
        @sys.exit(1)
        return
      }
      i += 1
      separator = args[i]
    } else if options && arg.has_prefix("-s") && arg.length() > 2 {
      separator = arg[2:].to_owned()
    } else if options && arg.has_prefix("--separator=") {
      separator = arg[12:].to_owned()
    } else if options && arg == "--help" {
      @stdio.stdout.write(
        "Usage: seq [-w] [-s STRING] [FIRST [INCREMENT]] LAST\n",
      )
      return
    } else if options &&
      arg.has_prefix("-") &&
      arg.length() > 1 &&
      !(arg[1] is ('0'..='9' | '.')) {
      @stdio.stderr.write("seq: invalid option: '\{arg}'\n")
      @sys.exit(1)
      return
    } else {
      operands.push(arg)
    }
    i += 1
  }
  if operands.length() < 1 || operands.length() > 3 {
    @stdio.stderr.write("seq: expected one to three operands\n")
    @sys.exit(1)
    return
  }
  let parsed : Array[Double] = []
  for operand in operands {
    let number = parse_number(operand) catch {
      _ => {
        @stdio.stderr.write("seq: invalid number: '\{operand}'\n")
        @sys.exit(1)
        return
      }
    }
    parsed.push(number)
  }
  let (first, step, last) = match parsed {
    [last] => (1.0, 1.0, last)
    [first, last] => (first, 1.0, last)
    [first, step, last] => (first, step, last)
    _ => (0.0, 0.0, 0.0)
  }
  if step == 0.0 {
    @stdio.stderr.write("seq: zero increment\n")
    @sys.exit(1)
    return
  }
  let first_text = first.to_string()
  let last_text = last.to_string()
  let width = if first_text.length() > last_text.length() {
    first_text.length()
  } else {
    last_text.length()
  }
  let mut current = first
  let mut emitted = 0
  let mut iterations = 0
  while (step > 0.0 && current <= last) || (step < 0.0 && current >= last) {
    if emitted > 0 {
      @stdio.stdout.write(separator)
    }
    let rendered = current.to_string()
    @stdio.stdout.write(
      if equal_width {
        zero_pad(rendered, width)
      } else {
        rendered
      },
    )
    emitted += 1
    iterations += 1
    if iterations > 10000000 {
      @stdio.stderr.write("seq: output limit exceeded\n")
      @sys.exit(1)
      return
    }
    current += step
  }
  if emitted > 0 {
    @stdio.stdout.write("\n")
  }
}
