///|
pub fn split_rule_separator(
  text : String,
  separator : Char,
) -> (String, String)? {
  let chars = text.iter().collect()
  let closes : Array[Char] = []
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '\\' {
      index += 2
      continue
    }
    if chars[index] == '#' && closes.is_empty() {
      return None
    }
    if chars[index] == '$' && chars.get(index + 1) is Some('(' | '{' as open) {
      closes.push(if open == '(' { ')' } else { '}' })
      index += 2
      continue
    }
    if closes.last() == Some(')') && chars[index] == '(' {
      closes.push(')')
    } else if closes.last() == Some('}') && chars[index] == '{' {
      closes.push('}')
    } else if closes.last() == Some(chars[index]) {
      ignore(closes.pop())
    } else if chars[index] == separator && closes.is_empty() {
      return Some(
        (
          String::from_array(chars[:index]),
          String::from_array(chars[index + 1:]),
        ),
      )
    }
    index += 1
  }
  None
}

///|
pub fn split_inline_recipe(text : String) -> (String, String?) {
  match split_rule_separator(text, ';') {
    Some((rule, recipe)) => (rule, Some(recipe))
    None => (text, None)
  }
}
