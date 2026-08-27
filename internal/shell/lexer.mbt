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
    tokens.push(WordToken({ parts: parts.copy(), preserve_empty }))
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
    '(' => raise ShellError("command substitution is not supported")
    '{' => {
      let mut end = start + 2
      while end < chars.length() && chars[end] != '}' {
        end += 1
      }
      if end >= chars.length() {
        raise ShellError("unterminated variable expansion")
      }
      let name = String::from_array(chars[start + 2:end])
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
  if script.length() > 4 * 1024 * 1024 {
    raise ShellError("script exceeds 4 MiB safety limit")
  }
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
          if tokens.last() != Some(Sequence) {
            tokens.push(Sequence)
          }
          i += 1
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
              raise ShellError("here-documents are not supported")
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
        } else if char == '(' || char == ')' || char == '{' || char == '}' {
          raise ShellError("compound commands are not supported")
        } else {
          literal.write_char(char)
          started = true
          i += 1
        }
    }
    if tokens.length() > 1_000_000 {
      raise ShellError("script contains too many tokens")
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
