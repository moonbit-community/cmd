///|
priv suberror SuffixError {
  SuffixError(String)
}

///|
priv struct SuffixFormat {
  prefix : String
  suffix : String
  conversion : UInt16
  width : Int32
  precision : Int32?
  left : Bool
  zero : Bool
  alternate : Bool
}

///|
fn suffix_format(value : String) -> SuffixFormat raise {
  let before = StringBuilder()
  let after = StringBuilder()
  let mut found = None
  let mut index = 0
  while index < value.length() {
    let literal = if found is None { before } else { after }
    if value[index] != '%' {
      literal.write_char(value[index].to_int().unsafe_to_char())
      index += 1
      continue
    }
    index += 1
    if index < value.length() && value[index] == '%' {
      literal.write_char('%')
      index += 1
      continue
    }
    guard found is None else {
      raise SuffixError("too many % conversion specifications in suffix")
    }
    let mut left = false
    let mut zero = false
    let mut alternate = false
    let mut thousands = false
    while index < value.length() && value[index] is ('-' | '0' | '#' | '\'') {
      match value[index] {
        '-' => left = true
        '0' => zero = true
        '#' => alternate = true
        _ => thousands = true
      }
      index += 1
    }
    let start = index
    while index < value.length() && value[index] is ('0'..<='9') {
      index += 1
    }
    let width = if index == start {
      0
    } else {
      @string.parse_int(value[start:index])
    }
    let precision = if index < value.length() && value[index] == '.' {
      index += 1
      let start = index
      while index < value.length() && value[index] is ('0'..<='9') {
        index += 1
      }
      Some(
        if start == index {
          0
        } else {
          @string.parse_int(value[start:index])
        },
      )
    } else {
      None
    }
    guard index < value.length() else {
      raise SuffixError("missing conversion specifier in suffix")
    }
    let conversion = value[index]
    guard conversion is ('d' | 'i' | 'u' | 'o' | 'x' | 'X') else {
      let octal = conversion.to_int().to_string(radix=8)
      let display = if conversion >= ' ' && conversion <= '~' {
        conversion.to_int().unsafe_to_char().to_string()
      } else {
        "\\" + "0".repeat(@cmp.maximum(0, 3 - octal.length())) + octal
      }
      raise SuffixError("invalid conversion specifier in suffix: " + display)
    }
    let decimal = conversion is ('d' | 'i' | 'u')
    if (decimal && alternate) || (!decimal && thousands) {
      let flag = if decimal { "#" } else { "'" }
      let conversion : UInt16 = if conversion == 'u' { 'd' } else { conversion }
      raise SuffixError(
        "invalid flags in conversion specification: %" +
        flag +
        conversion.to_int().unsafe_to_char().to_string(),
      )
    }
    found = Some((conversion, width, precision, left, zero, alternate))
    index += 1
  }
  guard found is Some((conversion, width, precision, left, zero, alternate)) else {
    raise SuffixError("missing % conversion specification in suffix")
  }
  {
    prefix: before.to_string(),
    suffix: after.to_string(),
    conversion,
    width,
    precision,
    left,
    zero,
    alternate,
  }
}

///|
fn SuffixFormat::render(self : SuffixFormat, number : Int32) -> String {
  let radix = match self.conversion {
    'o' => 8
    'x' | 'X' => 16
    _ => 10
  }
  let mut digits = if number == 0 && self.precision == Some(0) {
    ""
  } else {
    number.to_string(radix~)
  }
  if self.conversion == 'X' {
    digits = digits.to_upper()
  }
  let precision = self.precision.unwrap_or(1)
  digits = "0".repeat(@cmp.maximum(0, precision - digits.length())) + digits
  let mut marker = ""
  if self.alternate {
    if radix == 8 && !digits.has_prefix("0") {
      marker = "0"
    } else if radix == 16 && number != 0 {
      marker = if self.conversion == 'X' { "0X" } else { "0x" }
    }
  }
  let padding = @cmp.maximum(0, self.width - marker.length() - digits.length())
  let value = if self.left {
    marker + digits + " ".repeat(padding)
  } else if self.zero && self.precision is None {
    marker + "0".repeat(padding) + digits
  } else {
    " ".repeat(padding) + marker + digits
  }
  self.prefix + value + self.suffix
}
