///|
priv suberror SeqError {
  SeqError(String)
}

///|
priv struct Decimal {
  coefficient : BigInt
  scale : Int
}

///|
fn pow10(exponent : Int) -> BigInt {
  let mut value = BigInt::from_int(1)
  for _ in 0..<exponent {
    value = value * BigInt::from_int(10)
  }
  value
}

///|
fn Decimal::normalize(self : Decimal) -> Decimal {
  let ten = BigInt::from_int(10)
  let mut coefficient = self.coefficient
  let mut scale = self.scale
  while scale > 0 && (coefficient % ten).is_zero() {
    coefficient = coefficient / ten
    scale -= 1
  }
  { coefficient, scale, }
}

///|
fn parse_decimal(text : String) -> Decimal raise SeqError {
  if text == "" || text.contains("_") || text.length() > 4096 {
    raise SeqError("invalid number: '\{text}'")
  }
  let chars : Array[Char] = text.iter().collect()
  let mut start = 0
  let mut negative = false
  if chars[0] == '+' || chars[0] == '-' {
    negative = chars[0] == '-'
    start = 1
  }
  if start == chars.length() {
    raise SeqError("invalid number: '\{text}'")
  }
  let mut exponent_index = -1
  for index in start..<chars.length() {
    if chars[index] == 'e' || chars[index] == 'E' {
      if exponent_index >= 0 {
        raise SeqError("invalid number: '\{text}'")
      }
      exponent_index = index
    }
  }
  let mantissa_end = if exponent_index < 0 {
    chars.length()
  } else {
    exponent_index
  }
  let exponent = if exponent_index < 0 {
    0
  } else {
    let exponent_text = text[exponent_index + 1:].to_owned()
    @string.parse_int(exponent_text) catch {
      _ => raise SeqError("invalid exponent: '\{text}'")
    }
  }
  if exponent > 4096 || exponent < -4096 {
    raise SeqError("exponent out of supported range: '\{text}'")
  }
  let digits = StringBuilder()
  let mut decimal_seen = false
  let mut fractional_digits = 0
  for index in start..<mantissa_end {
    match chars[index] {
      '0'..='9' as digit => {
        digits.write_char(digit)
        if decimal_seen {
          fractional_digits += 1
        }
      }
      '.' if !decimal_seen => decimal_seen = true
      _ => raise SeqError("invalid number: '\{text}'")
    }
  }
  if digits.is_empty() {
    raise SeqError("invalid number: '\{text}'")
  }
  let mut coefficient = @string.parse_bigint(digits.to_string()) catch {
    _ => raise SeqError("number out of range: '\{text}'")
  }
  if negative {
    coefficient = -coefficient
  }
  let scale = fractional_digits - exponent
  if scale > 4096 || scale < -4096 {
    raise SeqError("number precision exceeds the supported limit: '\{text}'")
  }
  if scale < 0 {
    coefficient = coefficient * pow10(-scale)
    return ({ coefficient, scale: 0, } : Decimal).normalize()
  }
  ({ coefficient, scale, } : Decimal).normalize()
}

///|
fn Decimal::at_scale(self : Decimal, scale : Int) -> BigInt {
  if scale == self.scale {
    self.coefficient
  } else {
    self.coefficient * pow10(scale - self.scale)
  }
}

///|
fn Decimal::compare(self : Decimal, other : Decimal) -> Int {
  let scale = if self.scale > other.scale { self.scale } else { other.scale }
  self.at_scale(scale).compare(other.at_scale(scale))
}

///|
fn Decimal::add(self : Decimal, other : Decimal) -> Decimal {
  let scale = if self.scale > other.scale { self.scale } else { other.scale }
  (
    { coefficient: self.at_scale(scale) + other.at_scale(scale), scale, } :
    Decimal).normalize()
}

///|
fn Decimal::render(self : Decimal) -> String {
  let negative = self.coefficient.compare_int(0) < 0
  let absolute = if negative { -self.coefficient } else { self.coefficient }
  let digits = absolute.to_string()
  let body = if self.scale == 0 {
    digits
  } else if digits.length() <= self.scale {
    "0." + "0".repeat(self.scale - digits.length()) + digits
  } else {
    let split = digits.length() - self.scale
    digits[:split].to_owned() + "." + digits[split:].to_owned()
  }
  if negative {
    "-" + body
  } else {
    body
  }
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
    } else if options && arg == "--version" {
      @stdio.stdout.write("seq (moonbit cmd) 0.1.3\n")
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
  let parsed : Array[Decimal] = []
  for operand in operands {
    let number = parse_decimal(operand) catch {
      SeqError(message) => {
        @stdio.stderr.write("seq: \{message}\n")
        @sys.exit(1)
        return
      }
    }
    parsed.push(number)
  }
  let (first, step, last) = match parsed {
    [last] => (parse_decimal("1"), parse_decimal("1"), last)
    [first, last] => (first, parse_decimal("1"), last)
    [first, step, last] => (first, step, last)
    _ => abort("unreachable")
  }
  let step_direction = step.coefficient.compare_int(0)
  if step_direction == 0 {
    @stdio.stderr.write("seq: zero increment\n")
    @sys.exit(1)
    return
  }
  let first_text = first.render()
  let last_text = last.render()
  let width = if first_text.length() > last_text.length() {
    first_text.length()
  } else {
    last_text.length()
  }
  let mut current = first
  let mut emitted = 0
  while (step_direction > 0 && current.compare(last) <= 0) ||
        (step_direction < 0 && current.compare(last) >= 0) {
    if emitted > 0 {
      @stdio.stdout.write(separator)
    }
    let rendered = current.render()
    @stdio.stdout.write(
      if equal_width {
        zero_pad(rendered, width)
      } else {
        rendered
      },
    )
    emitted += 1
    if emitted > 10_000_000 {
      @stdio.stderr.write("seq: output limit exceeded\n")
      @sys.exit(1)
      return
    }
    current = current.add(step)
  }
  if emitted > 0 {
    @stdio.stdout.write("\n")
  }
}
