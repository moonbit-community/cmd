///|
enum Pattern {
  Line(Int32)
  Expression(@bytere.Pattern, Int32, Bool)
}

///|
struct Control {
  pattern : Pattern
  repeats : Int32?
}

///|
fn parse_pattern(value : String) -> Pattern raise {
  guard !value.is_empty() else { fail("empty pattern") }
  if value.has_prefix("/") || value.has_prefix("%") {
    let delimiter = value[0]
    let mut end = 1
    while end < value.length() {
      if value[end] == '\\' && end + 1 < value.length() {
        end += 2
        continue
      }
      if value[end] == delimiter {
        break
      }
      end += 1
    }
    guard end < value.length() else { fail("missing regex delimiter") }
    let offset = if end + 1 == value.length() {
      0
    } else {
      @string.parse_int(value[end + 1:])
    }
    Expression(
      @bytere.compile(@bytere.argument(value[1:end].to_owned())),
      offset,
      delimiter == '%',
    )
  } else {
    let number = @string.parse_int(value)
    guard number > 0 else { fail("line number must be positive") }
    Line(number)
  }
}

///|
fn parse_controls(values : ArrayView[String]) -> Array[Control] raise {
  let controls : Array[Control] = []
  let mut index = 0
  while index < values.length() {
    let pattern = parse_pattern(values[index])
    let mut repeats = Some(0)
    if index + 1 < values.length() && values[index + 1].has_prefix("{") {
      index += 1
      let repeat = values[index]
      guard repeat.has_suffix("}") else {
        fail("missing closing brace in repeat")
      }
      if repeat == "{*}" {
        repeats = None
      } else {
        let count = @string.parse_int(repeat[1:repeat.length() - 1])
        guard count >= 0 else { fail("repeat count must not be negative") }
        repeats = Some(count)
      }
    }
    controls.push({ pattern, repeats, })
    index += 1
  }
  controls
}

///|
fn line_starts(data : Bytes) -> Array[Int32] {
  let result = [0]
  for index in 0..<data.length() {
    if data[index] == b'\n' {
      result.push(index + 1)
    }
  }
  if result[result.length() - 1] != data.length() {
    result.push(data.length())
  }
  result
}

///|
fn line_text(data : Bytes, start : Int32, end : Int32) -> String {
  let output = StringBuilder()
  let end = if end > start && data[end - 1] == b'\n' { end - 1 } else { end }
  for index in start..<end {
    output.write_char(data[index].to_int().unsafe_to_char())
  }
  output.to_string()
}
