///|
priv suberror SplitError {
  SplitError(String)
}

///|
fn split_space(char : Char) -> Bool {
  char is (' ' | '\t' | '\n' | '\r' | '\u000b' | '\u000c')
}

///|
fn variable_start(char : Char) -> Bool {
  char is ('a'..<='z' | 'A'..<='Z' | '_')
}

///|
fn split_string(
  text : String,
  environment : Map[String, String],
) -> Array[String] raise SplitError {
  let chars = text.iter().collect()
  let result : Array[String] = []
  let word = StringBuilder()
  let mut quote : Char? = None
  let mut started = false
  let mut index = 0
  while index < chars.length() {
    let char = chars[index]
    if (char == '\'' && quote != Some('"')) ||
      (char == '"' && quote != Some('\'')) {
      quote = if quote is Some(_) { None } else { Some(char) }
      started = true
      index += 1
      continue
    }
    if split_space(char) && quote is None {
      if started {
        result.push(word.to_string())
        word.reset()
        started = false
      }
      index += 1
      continue
    }
    if char == '#' && !started {
      break
    }
    if char == '\\' {
      if quote == Some('\'') &&
        index + 1 < chars.length() &&
        !(chars[index + 1] is ('\\' | '\'')) {
        word.write_char(char)
        started = true
        index += 1
        continue
      }
      if index + 1 == chars.length() {
        if quote == Some('\'') {
          word.write_char(char)
          index += 1
          continue
        }
        raise SplitError("invalid backslash at end of string in -S")
      }
      let escaped = chars[index + 1]
      index += 2
      if escaped == '_' && quote != Some('"') {
        if started {
          result.push(word.to_string())
          word.reset()
          started = false
        }
        continue
      }
      if escaped == 'c' {
        if quote == Some('"') {
          raise SplitError("'\\c' must not appear in double-quoted -S string")
        }
        break
      }
      let decoded = match escaped {
        '"' | '#' | '$' | '\'' | '\\' => escaped
        '_' => ' '
        'f' => '\u000c'
        'n' => '\n'
        'r' => '\r'
        't' => '\t'
        'v' => '\u000b'
        _ => raise SplitError("invalid sequence '\\\{escaped}' in -S")
      }
      word.write_char(decoded)
      started = true
      continue
    }
    if char == '$' && quote != Some('\'') {
      let begin = index
      if index + 2 >= chars.length() ||
        chars[index + 1] != '{' ||
        !variable_start(chars[index + 2]) {
        raise SplitError(
          "only ${VARNAME} expansion is supported, error at: " +
          String::from_array(chars[begin:]),
        )
      }
      index += 3
      while index < chars.length() &&
            (variable_start(chars[index]) || chars[index] is ('0'..<='9')) {
        index += 1
      }
      if index == chars.length() || chars[index] != '}' {
        raise SplitError(
          "only ${VARNAME} expansion is supported, error at: " +
          String::from_array(chars[begin:]),
        )
      }
      let name = String::from_array(chars[begin + 2:index])
      if environment.get(name) is Some(value) {
        word.write_string(value)
        started = true
      }
      index += 1
      continue
    }
    word.write_char(char)
    started = true
    index += 1
  }
  if quote is Some(_) {
    raise SplitError("no terminating quote in -S string")
  }
  if started {
    result.push(word.to_string())
  }
  result
}
