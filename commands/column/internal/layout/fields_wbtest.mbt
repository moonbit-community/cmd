///|
fn Separator::split(self : Separator, line : String) -> Array[String] {
  let fields : Array[String] = []
  let mut start = 0
  for index, char in line {
    if char.to_int() < 128 && self.members[char.to_int()] {
      if self.preserve_empty || index > start {
        fields.push(line[start:index].to_owned())
      }
      start = index + 1
    }
  }
  if self.preserve_empty || start < line.length() {
    fields.push(line[start:].to_owned())
  }
  fields
}

///|
test "column compiles ASCII separator membership without changing empty fields" {
  for
    separator in [
      None,
      Some(""),
      Some(":"),
      Some("a\tb"),
      Some("::,"),
      Some("\u0000"),
    ] {
    let plan = Separator::new(separator)
    for length in [0, 1, 7, 128, 257] {
      let line = @utf8.decode(
        Bytes::makei(length, index => (index % 128).to_byte()),
      )
      assert_eq(plan.split(line), split_fields_reference(line, separator))
    }
  }
}

///|
fn split_fields_reference(line : String, separator : String?) -> Array[String] {
  let fields : Array[String] = []
  let delimiters = separator.unwrap_or(" \t")
  let mut start = 0
  for index, char in line {
    if delimiters.contains(char.to_string()) {
      if separator is Some(_) || index > start {
        fields.push(line[start:index].to_owned())
      }
      start = index + 1
    }
  }
  if separator is Some(_) || start < line.length() {
    fields.push(line[start:].to_owned())
  }
  fields
}

///|
test "byte fields preserve empty delimiters and control-sequence widths" {
  for separator in [None, Some(""), Some(":"), Some(" \t,:")] {
    let split = Separator::new(separator)
    for
      line in [
        "", "::", "a:b,,c", "\u001b[31mred\u001b[0m:next", "x\t[broken:z", "\u0000[1m:a",
      ] {
      let data = @utf8.encode(line)
      let reference = split_fields_reference(line, separator)
      let fields = split.table_fields(data[:])
      assert_eq(fields.length(), reference.length())
      for i, field in fields {
        assert_eq(@utf8.decode(field.data), reference[i])
        assert_eq(field.width, display_width(reference[i], table=true))
      }
    }
  }
}
