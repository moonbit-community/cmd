///|
priv struct FloatFormat {
  prefix : String
  suffix : String
  conversion : Char
  width : Int32?
  precision : Int32?
  left : Bool
  plus : Bool
  space : Bool
  zero : Bool
  alternate : Bool
}

///|
let sequence_profile : @numfmt.Profile = @numfmt.Extended80

///|
fn parse_float_format(text : String) -> FloatFormat raise SeqError {
  let chars : Array[Char] = text.iter().collect()
  let prefix = StringBuilder()
  let suffix = StringBuilder()
  let mut index = 0
  while index < chars.length() {
    if chars[index] != '%' {
      prefix.write_char(chars[index])
      index += 1
    } else if index + 1 < chars.length() && chars[index + 1] == '%' {
      prefix.write_char('%')
      index += 2
    } else {
      break
    }
  }
  if index == chars.length() {
    raise SeqError("format '\{text}' has no % directive")
  }
  index += 1
  let mut left = false
  let mut plus = false
  let mut space = false
  let mut zero = false
  let mut alternate = false
  while index < chars.length() {
    match chars[index] {
      '-' => left = true
      '+' => plus = true
      ' ' => space = true
      '0' => zero = true
      '#' => alternate = true
      '\'' => ()
      _ => break
    }
    index += 1
  }
  let mut width : Int32? = None
  let digits = StringBuilder()
  while index < chars.length() && chars[index] is ('0'..<='9') {
    digits.write_char(chars[index])
    index += 1
  }
  if !digits.is_empty() {
    width = Some(
      @string.parse_int(digits.to_string()) catch {
        _ => raise SeqError("format field width is out of range")
      },
    )
  }
  let mut precision : Int32? = None
  if index < chars.length() && chars[index] == '.' {
    index += 1
    let digits = StringBuilder()
    while index < chars.length() && chars[index] is ('0'..<='9') {
      digits.write_char(chars[index])
      index += 1
    }
    precision = Some(
      if digits.is_empty() {
        0
      } else {
        @string.parse_int(digits.to_string()) catch {
          _ => raise SeqError("format precision is out of range")
        }
      },
    )
  }
  if index < chars.length() && chars[index] == 'L' {
    index += 1
  }
  if index == chars.length() {
    raise SeqError("format '\{text}' ends in %")
  }
  let conversion = chars[index]
  if !(conversion is ('a' | 'A' | 'e' | 'E' | 'f' | 'F' | 'g' | 'G')) {
    raise SeqError("format '\{text}' has unknown %\{conversion} directive")
  }
  index += 1
  while index < chars.length() {
    if chars[index] != '%' {
      suffix.write_char(chars[index])
      index += 1
    } else if index + 1 < chars.length() && chars[index + 1] == '%' {
      suffix.write_char('%')
      index += 2
    } else {
      raise SeqError("format '\{text}' has too many % directives")
    }
  }
  {
    prefix: prefix.to_string(),
    suffix: suffix.to_string(),
    conversion,
    width,
    precision,
    left,
    plus,
    space,
    zero,
    alternate,
  }
}

///|
fn FloatFormat::field(self : FloatFormat, value : @numfmt.Value) -> String {
  let body = @numfmt.format_magnitude(
    value,
    self.conversion,
    self.precision,
    self.alternate,
    sequence_profile,
    normalized_hex=false,
  )
  let nonfinite = match value {
    @numfmt.Finite(_, _, _) => false
    _ => true
  }
  let sign = if value is @numfmt.NaN(_) {
    ""
  } else if value.is_negative() {
    "-"
  } else if self.plus {
    "+"
  } else if self.space {
    " "
  } else {
    ""
  }
  let (prefix, body) = if self.conversion is ('a' | 'A') && !nonfinite {
    (sign + body[:2].to_owned(), body[2:].to_owned())
  } else {
    (sign, body)
  }
  let length = prefix.length() + body.length()
  let padding = Int32::max(self.width.unwrap_or(0) - length, 0)
  if self.left {
    prefix + body + " ".repeat(padding)
  } else if self.zero && !nonfinite {
    prefix + "0".repeat(padding) + body
  } else {
    " ".repeat(padding) + prefix + body
  }
}

///|
fn parse_float_operand(text : String) -> @numfmt.Value raise SeqError {
  let (value, consumed, range_error) = @numfmt.parse_prefix(
    text, sequence_profile,
  )
  if consumed == 0 ||
    consumed != text.iter().count() ||
    (range_error && value is @numfmt.Infinity(_)) {
    raise SeqError(
      "invalid floating point argument: '\{text}'\nTry 'seq --help' for more information.",
    )
  }
  if value is @numfmt.NaN(_) {
    raise SeqError(
      "invalid 'not-a-number' argument: '\{text}'\nTry 'seq --help' for more information.",
    )
  }
  value
}

///|
async fn print_formatted(
  operands : Array[String],
  format : FloatFormat,
  separator : String,
) -> Unit {
  let parsed = operands.map(parse_float_operand)
  let one = @numfmt.parse_prefix("1", sequence_profile).0
  let (first, step, last) = match parsed {
    [last] => (one, one, last)
    [first, last] => (first, one, last)
    [first, step, last] => (first, step, last)
    _ => abort("unreachable")
  }
  let direction = @numfmt.compare(step, @numfmt.zero())
  if direction == 0 {
    let text = if operands.length() == 3 { operands[1] } else { "1" }
    raise SeqError(
      "invalid Zero increment value: '\{text}'\nTry 'seq --help' for more information.",
    )
  }
  let before_end = fn(value) {
    let order = @numfmt.compare(value, last)
    if direction < 0 {
      order >= 0
    } else {
      order <= 0
    }
  }
  if !before_end(first) {
    return
  }
  let output = @io.BufferedWriter::new(@stdio.stdout, size=65536)
  let mut current = first
  let mut index = BigInt::from_int(1)
  let mut emitted = false
  for ;; {
    if emitted {
      output.write(separator)
    }
    output.write(format.prefix)
    let field = format.field(current)
    output.write(field)
    output.write(format.suffix)
    emitted = true
    let next = @numfmt.sequence_value(first, step, index, sequence_profile)
    index = index + BigInt::from_int(1)
    if !before_end(next) {
      let next_field = format.field(next)
      let (recovered, consumed, range_error) = @numfmt.parse_prefix(
        next_field, sequence_profile,
      )
      if consumed == next_field.iter().count() &&
        consumed > 0 &&
        !range_error &&
        @numfmt.compare(recovered, last) == 0 &&
        next_field != field {
        output.write(separator)
        output.write(format.prefix)
        output.write(next_field)
        output.write(format.suffix)
      }
      break
    }
    current = next
  }
  output.write("\n")
  output.flush()
}
