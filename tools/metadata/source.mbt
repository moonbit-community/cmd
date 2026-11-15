///|
priv struct Token {
  text : String
}

///|
fn tokens(source : String) -> Array[Token] raise {
  let result : Array[Token] = []
  let mut index = 0
  while index < source.length() {
    let unit = source[index]
    if unit is (' ' | '\t' | '\r' | '\n') {
      index += 1
      continue
    }
    if source[index:].has_prefix("//") {
      while index < source.length() && source[index] != '\n' {
        index += 1
      }
      continue
    }
    let start = index
    if unit is ('\"' | '\'') {
      index += 1
      let mut closed = false
      while index < source.length() {
        if source[index] == '\\' {
          index += 2
          continue
        }
        if source[index] == unit {
          index += 1
          closed = true
          break
        }
        index += 1
      }
      guard closed else { fail("unterminated source literal") }
    } else if source[index:].has_prefix("#|") || source[index:].has_prefix("$|") {
      while index < source.length() && source[index] != '\n' {
        index += 1
      }
    } else if unit is ('a'..<='z' | 'A'..<='Z' | '_' | '0'..<='9') {
      index += 1
      while index < source.length() &&
            source[index] is ('a'..<='z' | 'A'..<='Z' | '_' | '0'..<='9') {
        index += 1
      }
    } else {
      index += 1
    }
    result.push({ text: source[start:index].to_owned(), })
  }
  // Moon's formatter removes a trailing comma when a collection fits on one line.
  let normalized : Array[Token] = []
  for index, token in result {
    if token.text == "," &&
      index + 1 < result.length() &&
      ["]", ")", "}"].contains(result[index + 1].text) {
      continue
    }
    normalized.push(token)
  }
  normalized
}

///|
fn quoted(value : String) -> String {
  Json(value).stringify()
}

///|
fn string_literal(value : String) -> String raise {
  guard @json.parse(value) is String(text) else {
    fail("expected string literal")
  }
  text
}

///|
async fn module_field(path : String, key : String) -> String {
  let values = @fs.read_file(path)
    .text()
    .split("\n")
    .filter_map(line => {
      line.trim().strip_prefix(key + " = ").map(StringView::to_owned)
    })
    .collect()
  guard values is [value] else { fail("expected one " + key + " in " + path) }
  string_literal(value)
}

///|
async fn output(path : String, content : String, check : Bool) -> Unit {
  if @fs.exists(path) {
    let current = @fs.read_file(path).text()
    if current == content {
      return
    }
    if path.has_suffix(".mbt") &&
      tokens(current).map(token => token.text) ==
      tokens(content).map(token => token.text) {
      return
    }
  }
  guard !check else { fail("generated metadata drift: " + path) }
  @fs.write_file(path, content)
}
