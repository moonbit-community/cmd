///|
fn is_name_start(char : Char) -> Bool {
  char == '_' || char is ('a'..='z' | 'A'..='Z')
}

///|
fn is_name_char(char : Char) -> Bool {
  is_name_start(char) || char is ('0'..='9')
}

///|
fn is_shell_space(char : Char) -> Bool {
  char == ' ' || char == '\t' || char == '\r'
}

///|
fn flush_literal(parts : Array[WordPart], literal : StringBuilder) -> Unit {
  if !literal.is_empty() {
    parts.push(Text(literal.to_string()))
    literal.reset()
  }
}

///|
fn push_word(
  tokens : Array[Token],
  parts : Array[WordPart],
  literal : StringBuilder,
  started : Bool,
  preserve_empty : Bool,
) -> Unit {
  if started {
    flush_literal(parts, literal)
    tokens.push(WordToken({ parts: parts.copy(), preserve_empty, }))
    parts.clear()
  }
}

///|
fn parse_dollar(
  chars : Array[Char],
  start : Int,
  quoted : Bool,
) -> (WordPart?, Int) raise ShellError {
  if start + 1 >= chars.length() {
    return (None, start + 1)
  }
  match chars[start + 1] {
    '?' => (Some(LastStatus(quoted)), start + 2)
    '#' => (Some(ArgCount(quoted)), start + 2)
    '@' => (Some(AllArgs(quoted, false)), start + 2)
    '*' => (Some(AllArgs(quoted, true)), start + 2)
    '0'..='9' as digit =>
      (Some(Positional(digit.to_int() - '0'.to_int(), quoted)), start + 2)
    '(' => {
      let mut depth = 1
      let mut end = start + 2
      while end < chars.length() {
        if chars[end] == '(' {
          depth += 1
        } else if chars[end] == ')' {
          depth -= 1
          if depth == 0 {
            return (
              Some(
                CommandSubstitution(
                  String::from_array(chars[start + 2:end]),
                  quoted,
                ),
              ),
              end + 1,
            )
          }
        }
        end += 1
      }
      raise ShellError("unterminated command substitution")
    }
    '{' => {
      let mut end = start + 2
      while end < chars.length() && chars[end] != '}' {
        end += 1
      }
      if end >= chars.length() {
        raise ShellError("unterminated variable expansion")
      }
      let raw_name = String::from_array(chars[start + 2:end])
      if raw_name.has_prefix("#") {
        let name = raw_name[1:].to_owned()
        if name == "" || !is_name_start(name.iter().next().unwrap()) {
          raise ShellError("invalid variable name: '\\{raw_name}'")
        }
        return (Some(LengthVariable(name, quoted)), end + 1)
      }
      let name = raw_name
      if name == "" || !is_name_start(name.iter().next().unwrap()) {
        raise ShellError("invalid variable name: '\{name}'")
      }
      for char in name {
        if !is_name_char(char) {
          raise ShellError("invalid variable name: '\{name}'")
        }
      }
      (Some(Variable(name, quoted)), end + 1)
    }
    char if is_name_start(char) => {
      let mut end = start + 2
      while end < chars.length() && is_name_char(chars[end]) {
        end += 1
      }
      (Some(Variable(String::from_array(chars[start + 1:end]), quoted)), end)
    }
    _ => (None, start + 1)
  }
}

///|
fn lex(script : String) -> Array[Token] raise ShellError {
  let chars : Array[Char] = script.iter().collect()
  let tokens : Array[Token] = []
  let parts : Array[WordPart] = []
  let literal = StringBuilder()
  let mut started = false
  let mut preserve_empty = false
  let mut quote : Char? = None
  let mut i = 0
  while i < chars.length() {
    let char = chars[i]
    match quote {
      Some('\'') => {
        if char == '\'' {
          quote = None
        } else {
          literal.write_char(char)
        }
        i += 1
      }
      Some('"') =>
        if char == '"' {
          quote = None
          i += 1
        } else if char == '\\' {
          if i + 1 >= chars.length() {
            raise ShellError("unterminated escape in double quote")
          }
          let next = chars[i + 1]
          if next == '\n' {
            i += 2
          } else if next == '$' || next == '"' || next == '\\' {
            literal.write_char(next)
            i += 2
          } else {
            literal.write_char('\\')
            literal.write_char(next)
            i += 2
          }
        } else if char == '$' {
          flush_literal(parts, literal)
          let (part, next) = parse_dollar(chars, i, true)
          match part {
            Some(value) => parts.push(value)
            None => literal.write_char('$')
          }
          i = next
        } else if char == '`' {
          raise ShellError("backtick command substitution is not supported")
        } else {
          literal.write_char(char)
          i += 1
        }
      Some(_) => raise ShellError("invalid internal quote state")
      None =>
        if is_shell_space(char) {
          push_word(tokens, parts, literal, started, preserve_empty)
          started = false
          preserve_empty = false
          i += 1
        } else if char == '\n' || char == ';' {
          push_word(tokens, parts, literal, started, preserve_empty)
          started = false
          preserve_empty = false
          if char == ';' && i + 1 < chars.length() && chars[i + 1] == ';' {
            tokens.push(CaseEnd)
            i += 2
          } else if tokens.last() != Some(Sequence) {
            tokens.push(Sequence)
            i += 1
          }
        } else if char == '#' && !started {
          while i < chars.length() && chars[i] != '\n' {
            i += 1
          }
        } else if char == '\'' || char == '"' {
          quote = Some(char)
          started = true
          preserve_empty = true
          i += 1
        } else if char == '\\' {
          if i + 1 >= chars.length() {
            raise ShellError("script ends with an unmatched backslash")
          }
          if chars[i + 1] == '\n' {
            i += 2
          } else {
            literal.write_char(chars[i + 1])
            started = true
            i += 2
          }
        } else if char == '$' {
          flush_literal(parts, literal)
          let (part, next) = parse_dollar(chars, i, false)
          match part {
            Some(value) => parts.push(value)
            None => literal.write_char('$')
          }
          started = true
          i = next
        } else if char == '`' {
          raise ShellError("backtick command substitution is not supported")
        } else if char == '&' {
          push_word(tokens, parts, literal, started, preserve_empty)
          started = false
          preserve_empty = false
          if i + 1 < chars.length() && chars[i + 1] == '&' {
            tokens.push(AndIf)
            i += 2
          } else {
            raise ShellError("background execution is not supported")
          }
        } else if char == '|' {
          push_word(tokens, parts, literal, started, preserve_empty)
          started = false
          preserve_empty = false
          if i + 1 < chars.length() && chars[i + 1] == '|' {
            tokens.push(OrIf)
            i += 2
          } else {
            tokens.push(Pipe)
            i += 1
          }
        } else if !started &&
          char == '2' &&
          i + 1 < chars.length() &&
          chars[i + 1] == '>' {
          if i + 2 < chars.length() && chars[i + 2] == '>' {
            tokens.push(RedirectErrorAppend)
            i += 3
          } else {
            tokens.push(RedirectError)
            i += 2
          }
        } else if char == '>' || char == '<' {
          push_word(tokens, parts, literal, started, preserve_empty)
          started = false
          preserve_empty = false
          if char == '<' {
            if i + 1 < chars.length() && chars[i + 1] == '<' {
              let mut delimiter_start = i + 2
              while delimiter_start < chars.length() &&
                    is_shell_space(chars[delimiter_start]) {
                delimiter_start += 1
              }
              let mut delimiter_end = delimiter_start
              while delimiter_end < chars.length() &&
                    chars[delimiter_end] != '\n' &&
                    !is_shell_space(chars[delimiter_end]) {
                delimiter_end += 1
              }
              if delimiter_end == delimiter_start {
                raise ShellError("here-document requires a delimiter")
              }
              let delimiter = String::from_array(
                chars[delimiter_start:delimiter_end],
              )
              let mut line_start = delimiter_end
              while line_start < chars.length() && chars[line_start] != '\n' {
                line_start += 1
              }
              if line_start >= chars.length() {
                raise ShellError("here-document must start on a new line")
              }
              line_start += 1
              let mut cursor = line_start
              let body = StringBuilder()
              let mut found = false
              while cursor <= chars.length() {
                let mut line_end = cursor
                while line_end < chars.length() && chars[line_end] != '\n' {
                  line_end += 1
                }
                let line = String::from_array(chars[cursor:line_end])
                if line == delimiter {
                  found = true
                  cursor = if line_end < chars.length() {
                    line_end + 1
                  } else {
                    line_end
                  }
                  break
                }
                body.write_string(line)
                if line_end < chars.length() {
                  body.write_char('\n')
                }
                if line_end >= chars.length() {
                  cursor = line_end
                  break
                }
                cursor = line_end + 1
              }
              if !found {
                raise ShellError("unterminated here-document")
              }
              tokens.push(RedirectHereDoc)
              tokens.push(
                WordToken({
                  parts: [Text(body.to_string())],
                  preserve_empty: true,
                }),
              )
              i = cursor
              continue
            }
            tokens.push(RedirectIn)
            i += 1
          } else if i + 1 < chars.length() && chars[i + 1] == '>' {
            tokens.push(RedirectAppend)
            i += 2
          } else {
            tokens.push(RedirectOut)
            i += 1
          }
        } else if char == '(' {
          push_word(tokens, parts, literal, started, preserve_empty)
          started = false
          preserve_empty = false
          tokens.push(LParen)
          i += 1
        } else if char == ')' {
          push_word(tokens, parts, literal, started, preserve_empty)
          started = false
          preserve_empty = false
          tokens.push(RParen)
          i += 1
        } else if char == '{' {
          push_word(tokens, parts, literal, started, preserve_empty)
          started = false
          preserve_empty = false
          tokens.push(LBrace)
          i += 1
        } else if char == '}' {
          push_word(tokens, parts, literal, started, preserve_empty)
          started = false
          preserve_empty = false
          tokens.push(RBrace)
          i += 1
        } else {
          literal.write_char(char)
          started = true
          i += 1
        }
    }
  }
  if quote is Some(_) {
    raise ShellError("unterminated quote")
  }
  push_word(tokens, parts, literal, started, preserve_empty)
  while tokens.last() == Some(Sequence) {
    ignore(tokens.pop())
  }
  tokens
}
