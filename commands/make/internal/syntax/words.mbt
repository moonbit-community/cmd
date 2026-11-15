///|
pub fn valid_variable_name(name : String) -> Bool {
  if name == "" {
    return false
  }
  for char in name {
    if char == ' ' || char == '\t' || char == ':' || char == '#' {
      return false
    }
  }
  true
}

///|
pub fn remove_comment(line : String) -> String {
  let output = StringBuilder()
  let mut escaped = false
  for char in line {
    if char == '#' && !escaped {
      break
    }
    if escaped && char != '#' {
      output.write_char('\\')
    }
    if char == '\\' {
      escaped = !escaped
    } else {
      output.write_char(char)
      escaped = false
    }
  }
  if escaped {
    output.write_char('\\')
  }
  output.to_string()
}

///|
pub fn split_words(value : String) -> Array[String] {
  let result : Array[String] = []
  let word = StringBuilder()
  for char in value {
    if char.is_whitespace() {
      if !word.is_empty() {
        result.push(word.to_string())
        word.reset()
      }
    } else {
      word.write_char(char)
    }
  }
  if !word.is_empty() {
    result.push(word.to_string())
  }
  result
}

///|
pub fn pattern_match(pattern : String, target : String) -> String? {
  guard pattern.split_once("%") is Some((prefix, suffix)) else { return None }
  if target.has_prefix(prefix) &&
    target.has_suffix(suffix) &&
    target.length() >= prefix.length() + suffix.length() {
    Some(target[prefix.length():target.length() - suffix.length()].to_owned())
  } else {
    None
  }
}

///|
pub fn trim_make_space_start(text : String) -> String {
  let mut start = 0
  while start < text.length() &&
        text[start] is (' ' | '\t' | '\r' | '\n' | '\u000b' | '\u000c') {
    start += 1
  }
  text[start:].to_owned()
}

///|
pub fn parse_assignment(line : String) -> (String, String, String)? {
  guard split_rule_separator(line, '=') is Some((left, right)) else {
    return None
  }
  let mut left = left
  let mut operator = "="
  for prefix in [":::", "::", ":", "!", "?", "+"] {
    if left.has_suffix(prefix) {
      left = left[:left.length() - prefix.length()].to_owned()
      operator = prefix + "="
      break
    }
  }
  let mut start = 0
  let mut end = left.length()
  while start < end && left[start] is (' ' | '\t') {
    start += 1
  }
  while end > start && left[end - 1] is (' ' | '\t') {
    end -= 1
  }
  let name = left[start:end].to_owned()
  // An assignment operator may contain colons; after removing it, any outer
  // colon belongs to a rule. Its recipe must not become a computed LHS.
  if split_rule_separator(name, ':') is Some(_) ||
    split_rule_separator(name, ' ') is Some(_) ||
    split_rule_separator(name, '\t') is Some(_) {
    return None
  }
  if valid_variable_name(name) || name.contains("$(") || name.contains("${") {
    Some((name, operator, trim_make_space_start(right)))
  } else {
    None
  }
}

///|
pub fn logical_lines(contents : String) -> Array[String] raise ParseError {
  let result : Array[String] = []
  let pending = StringBuilder()
  for raw_line in contents.split("\n") {
    let line = if raw_line.has_suffix("\r") {
      raw_line[:raw_line.length() - 1].to_owned()
    } else {
      raw_line.to_owned()
    }
    if line.has_prefix("\t") {
      if !pending.is_empty() {
        raise ParseError("recipe encountered during a continued logical line")
      }
      result.push(line)
    } else if line.has_suffix("\\") {
      pending.write_string(line[:line.length() - 1].to_owned())
      pending.write_char(' ')
    } else if pending.is_empty() {
      result.push(line)
    } else {
      pending.write_string(line)
      result.push(pending.to_string())
      pending.reset()
    }
  }
  if !pending.is_empty() {
    raise ParseError("Makefile ends with a continued line")
  }
  result
}

///|
pub(all) suberror ParseError {
  ParseError(String)
}
