///|
fn default_colors() -> Array[String] {
  ["0;90", "0;39", "0;39", "0;39", "0;32", "1;39", "1;39", "1;34"].map(code => {
    "\u{1b}[" + code + "m"
  })
}

///|
// jq 1.8.2 accepts partial palettes and resets the remaining slots to defaults.
// Empty intermediate slots mean SGR reset; an empty final slot is ignored.
fn parse_colors(value : String?) -> (Array[String], Bool) {
  let colors = default_colors()
  guard value is Some(text) else { return (colors, true) }
  let mut start = 0
  for slot in 0..<8 {
    let mut end = start
    while end < text.length() && text[end] is ('0'..='9' | ';') {
      end += 1
    }
    if end < text.length() && slot < 7 && text[end] != ':' {
      return (default_colors(), false)
    }
    if end == text.length() || slot == 7 {
      if end > start {
        colors[slot] = "\u{1b}[" + text[start:end].to_owned() + "m"
      }
      break
    }
    colors[slot] = "\u{1b}[" + text[start:end].to_owned() + "m"
    start = end + 1
  }
  (colors, true)
}

///|
fn json_color(value : Json) -> Int {
  match value {
    Null => 0
    False => 1
    True => 2
    Number(_, ..) => 3
    String(_) => 4
    Array(_) => 5
    Object(_) => 6
  }
}

///|
fn render_json(
  value : Json,
  pretty : Bool,
  indent : Int,
  tab : Bool,
  colors : Array[String]?,
) -> String {
  let output = StringBuilder()
  fn color(index : Int) -> Unit {
    if colors is Some(palette) {
      output.write_string(palette[index])
    }
  }
  fn reset() -> Unit {
    if colors is Some(_) {
      output.write_string("\u{1b}[0m")
    }
  }
  fn newline(depth : Int) -> Unit {
    if pretty {
      output.write_char('\n')
      for _ in 0..<(if tab { depth } else { depth * indent }) {
        output.write_char(if tab { '\t' } else { ' ' })
      }
    }
  }
  fn emit(value : Json, depth : Int) -> Unit {
    let tone = json_color(value)
    color(tone)
    match value {
      Array(items) if !items.is_empty() => {
        output.write_char('[')
        for index, item in items {
          if index > 0 {
            color(tone)
            output.write_char(',')
          }
          reset()
          newline(depth + 1)
          emit(item, depth + 1)
        }
        newline(depth)
        color(tone)
        output.write_char(']')
      }
      Object(fields) if !fields.is_empty() => {
        output.write_char('{')
        let mut first = true
        for name, item in fields {
          if !first {
            color(tone)
            output.write_char(',')
          }
          first = false
          reset()
          newline(depth + 1)
          color(7)
          output.write_string(Json::string(name).stringify())
          reset()
          color(tone)
          output.write_char(':')
          reset()
          if pretty {
            output.write_char(' ')
          }
          emit(item, depth + 1)
        }
        newline(depth)
        color(tone)
        output.write_char('}')
      }
      _ => output.write_string(value.stringify())
    }
    reset()
  }
  emit(value, 0)
  output.to_string()
}
