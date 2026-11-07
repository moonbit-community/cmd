///|
priv struct PendingHereDoc {
  delimiter : String
  expand : Bool
  strip_tabs : Bool
  token_index : Int32
}

///|
fn heredoc_delimiter(
  chars : Array[Char],
  start : Int32,
) -> (String, Bool, Int32) raise ParseIssue {
  let literal = StringBuilder()
  let mut cursor = start
  while cursor < chars.length() && is_shell_space(chars[cursor]) {
    cursor += 1
  }
  let begin = cursor
  if chars.get(cursor) == Some('#') {
    raise InvalidSyntax("here-document requires a delimiter")
  }
  let mut quote : Char? = None
  let mut quoted = false
  while cursor < chars.length() {
    let char = chars[cursor]
    if quote is Some(q) {
      if char == q {
        quote = None
      } else if q == '"' &&
        char == '\\' &&
        cursor + 1 < chars.length() &&
        chars[cursor + 1] is ('$' | '`' | '"' | '\\' | '\n') {
        cursor += 1
        if chars[cursor] != '\n' {
          literal.write_char(chars[cursor])
        }
      } else {
        literal.write_char(char)
      }
    } else if char == '\'' || char == '"' {
      quote = Some(char)
      quoted = true
    } else if char == '\\' {
      cursor += 1
      if cursor >= chars.length() {
        raise IncompleteSyntax("unterminated here-document delimiter escape")
      }
      if chars[cursor] != '\n' {
        quoted = true
        literal.write_char(chars[cursor])
      }
    } else if is_shell_space(char) ||
      char is ('\n' | ';' | '&' | '|' | '<' | '>' | '(' | ')') {
      break
    } else {
      literal.write_char(char)
    }
    cursor += 1
  }
  if quote is Some(_) {
    raise IncompleteSyntax("unterminated here-document delimiter quote")
  }
  if begin == cursor {
    if cursor >= chars.length() {
      raise IncompleteSyntax("here-document requires a delimiter")
    }
    raise InvalidSyntax("here-document requires a delimiter")
  }
  (literal.to_string(), !quoted, cursor)
}

///|
fn consume_heredocs(
  chars : Array[Char],
  start : Int32,
  pending : Array[PendingHereDoc],
  tokens : Array[Token],
) -> Int32 raise ParseIssue {
  let mut cursor = start
  for document in pending {
    let body = StringBuilder()
    let mut found = false
    while cursor <= chars.length() {
      let line = StringBuilder()
      let mut newline = false
      let mut first = true
      for ;; {
        let mut begin = cursor
        if document.strip_tabs && first {
          while begin < chars.length() && chars[begin] == '\t' {
            begin += 1
          }
        }
        first = false
        let mut end = begin
        while end < chars.length() && chars[end] != '\n' {
          end += 1
        }
        newline = end < chars.length()
        cursor = end + (if newline { 1 } else { 0 })
        let mut slashes = 0
        while end - slashes > begin && chars[end - slashes - 1] == '\\' {
          slashes += 1
        }
        if document.expand && newline && slashes % 2 == 1 {
          line.write_string(String::from_array(chars[begin:end - 1]))
        } else {
          line.write_string(String::from_array(chars[begin:end]))
          break
        }
      }
      let text = line.to_string()
      if text == document.delimiter {
        found = true
        break
      }
      body.write_string(text)
      if newline {
        body.write_char('\n')
      } else {
        break
      }
    }
    if !found {
      raise IncompleteSyntax("unterminated here-document")
    }
    tokens[document.token_index] = RedirectHereDoc(
      body.to_string(),
      document.expand,
    )
  }
  pending.clear()
  cursor
}
