///|
priv struct Names {
  digits : Array[Int32]
  options : Options
  mut first : Bool
}

///|
fn Names::new(options : Options) -> Names {
  let digits = Array::make(options.width, 0)
  if options.start is Some(value) {
    for index in 0..<value.length() {
      let character = value[index].to_int()
      digits[options.width - value.length() + index] = if character <= 57 {
        character - 48
      } else {
        character - 87
      }
    }
  }
  { digits, options, first: true, }
}

///|
fn advance_suffix(
  digits : Array[Int32],
  radix : Int32,
  automatic : Bool,
) -> Bool {
  let mut position = digits.length() - 1
  while position >= 0 {
    digits[position] += 1
    if digits[position] < radix {
      break
    }
    digits[position] = 0
    position -= 1
  }
  if position < 0 {
    return false
  }
  if automatic {
    let prefix_length = (digits.length() - 2) / 2
    if digits[prefix_length] == radix - 1 {
      digits.clear()
      for _ in 0..<(prefix_length + 1) {
        digits.push(radix - 1)
      }
      for _ in 0..<(prefix_length + 3) {
        digits.push(0)
      }
    }
  }
  true
}

///|
fn suffix_name(digits : Array[Int32], alphabet : String) -> String {
  let output = StringBuilder()
  for digit in digits {
    output.write_char(alphabet[digit].unsafe_to_char())
  }
  output.to_string()
}

///|
fn Names::next(self : Names) -> String raise SplitError {
  if self.first {
    self.first = false
  } else if !advance_suffix(
      self.digits,
      self.options.alphabet.length(),
      self.options.automatic,
    ) {
    raise SplitError(1, "output file suffixes exhausted")
  }
  self.options.prefix +
  suffix_name(self.digits, self.options.alphabet) +
  self.options.additional
}
