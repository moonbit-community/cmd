///|
fn is_name_start(char : Char) -> Bool {
  char == '_' || char is ('a'..<='z' | 'A'..<='Z')
}

///|
fn is_name_char(char : Char) -> Bool {
  is_name_start(char) || char is ('0'..<='9')
}

///|
fn is_shell_space(char : Char) -> Bool {
  char == ' ' || char == '\t' || char == '\r'
}

///|
fn flush_literal(
  parts : Array[WordPart],
  literal : StringBuilder,
  quoted~ : Bool = false,
) -> Unit {
  if !literal.is_empty() {
    parts.push(
      if quoted {
        QuotedText(literal.to_string())
      } else {
        Text(literal.to_string())
      },
    )
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
fn parse_backtick_input(
  chars : Array[Char],
  start : Int32,
  quoted : Bool,
) -> (WordPart, Int32) raise ParseIssue {
  let source = StringBuilder()
  let mut cursor = start + 1
  while cursor < chars.length() {
    let char = chars[cursor]
    if char == '`' {
      return (CommandSubstitution(source.to_string(), quoted), cursor + 1)
    }
    if char == '\\' && cursor + 1 < chars.length() {
      let next = chars[cursor + 1]
      if next is ('$' | '`' | '\\' | '\n') || (quoted && next == '"') {
        if next != '\n' {
          source.write_char(next)
        }
        cursor += 2
        continue
      }
    }
    source.write_char(char)
    cursor += 1
  }
  raise IncompleteSyntax("unterminated backtick command substitution")
}

///|
fn parse_dollar_input(
  chars : Array[Char],
  start : Int32,
  quoted : Bool,
) -> (WordPart?, Int32) raise ParseIssue {
  if start + 1 >= chars.length() {
    return (None, start + 1)
  }
  match chars[start + 1] {
    '?' => (Some(LastStatus(quoted)), start + 2)
    '#' => (Some(ArgCount(quoted)), start + 2)
    '@' => (Some(AllArgs(quoted, false)), start + 2)
    '*' => (Some(AllArgs(quoted, true)), start + 2)
    '0'..<='9' as digit =>
      (Some(Positional(digit.to_int() - '0'.to_int(), quoted)), start + 2)
    '(' => {
      let arithmetic = chars.get(start + 2) == Some('(')
      let mut depth = 1
      let mut end = start + 2
      let mut quote : Char? = None
      let mut word_start = true
      let heredocs : Array[PendingHereDoc] = []
      let document_tokens : Array[Token] = []
      while end < chars.length() {
        if quote is Some(q) {
          if q == '"' &&
            chars[end] == '$' &&
            chars.get(end + 1) is Some('(' | '{') {
            let (_, next) = parse_dollar_input(chars, end, true)
            end = next
            continue
          } else if q == '"' && chars[end] == '`' {
            let (_, next) = parse_backtick_input(chars, end, true)
            end = next
            continue
          } else if chars[end] == q {
            quote = None
          } else if chars[end] == '\\' && q == '"' {
            end += 1
          }
        } else if chars[end] == '$' && chars.get(end + 1) is Some('(' | '{') {
          let (_, next) = parse_dollar_input(chars, end, false)
          end = next
          word_start = false
          continue
        } else if !arithmetic && chars[end] == '#' && word_start {
          while end < chars.length() && chars[end] != '\n' {
            end += 1
          }
          continue
        } else if !arithmetic &&
          chars[end] == '<' &&
          chars.get(end + 1) == Some('<') {
          let strip_tabs = chars.get(end + 2) == Some('-')
          let (delimiter, expand, next) = heredoc_delimiter(
            chars,
            end + (if strip_tabs { 3 } else { 2 }),
          )
          heredocs.push({
            delimiter,
            expand,
            strip_tabs,
            token_index: document_tokens.length(),
          })
          document_tokens.push(RedirectHereDoc("", expand))
          end = next
          word_start = false
          continue
        } else if chars[end] == '\n' && !heredocs.is_empty() {
          end = consume_heredocs(chars, end + 1, heredocs, document_tokens)
          word_start = true
          continue
        } else if chars[end] == '`' {
          let (_, next) = parse_backtick_input(chars, end, false)
          end = next
          word_start = false
          continue
        } else if chars[end] == '\\' {
          let continuation = chars.get(end + 1) == Some('\n')
          end += 2
          if !continuation {
            word_start = false
          }
          continue
        } else if chars[end] == '\'' || chars[end] == '"' {
          quote = Some(chars[end])
          word_start = false
        } else if chars[end] == '(' {
          depth += 1
        } else if chars[end] == ')' {
          if !arithmetic {
            let source = String::from_array(chars[start + 2:end + 1])
            if command_substitution_closes(source) {
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
            end += 1
            word_start = true
            continue
          }
          depth -= 1
          if depth == 0 {
            if arithmetic {
              if chars.get(end - 1) != Some(')') {
                raise InvalidSyntax("invalid arithmetic expansion")
              }
              return (
                Some(
                  Arithmetic(
                    String::from_array(chars[start + 3:end - 1]),
                    quoted,
                  ),
                ),
                end + 1,
              )
            }
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
        if quote is None {
          word_start = is_shell_space(chars[end]) ||
            chars[end] is ('\n' | ';' | '&' | '|' | '<' | '>' | '(' | ')')
        }
        end += 1
      }
      raise IncompleteSyntax("unterminated command substitution")
    }
    '{' => {
      let mut end = start + 2
      let mut depth = 1
      while end < chars.length() {
        if chars[end] == '{' {
          depth += 1
        }
        if chars[end] == '}' {
          depth -= 1
          if depth == 0 {
            break
          }
        }
        end += 1
      }
      if end >= chars.length() {
        raise IncompleteSyntax("unterminated variable expansion")
      }
      let raw_name = String::from_array(chars[start + 2:end])
      let raw_chars = raw_name.iter().collect()
      let mut name_end = 0
      while name_end < raw_chars.length() && is_name_char(raw_chars[name_end]) {
        name_end += 1
      }
      if name_end > 0 &&
        name_end < raw_chars.length() &&
        is_name_start(raw_chars[0]) {
        let mut op_end = name_end
        if raw_chars[op_end] == ':' {
          op_end += 1
        }
        if op_end < raw_chars.length() &&
          raw_chars[op_end] is ('-' | '+' | '=' | '?') {
          op_end += 1
          return (
            Some(
              DefaultVariable(
                String::from_array(raw_chars[:name_end]),
                String::from_array(raw_chars[name_end:op_end]),
                String::from_array(raw_chars[op_end:]),
                quoted,
              ),
            ),
            end + 1,
          )
        }
      }
      if raw_name.has_prefix("#") {
        let name = raw_name[1:].to_owned()
        if name == "" || !is_name_start(name.iter().next().unwrap()) {
          raise InvalidSyntax("invalid variable name: '\\{raw_name}'")
        }
        return (Some(LengthVariable(name, quoted)), end + 1)
      }
      let name = raw_name
      if name == "" || !is_name_start(name.iter().next().unwrap()) {
        raise InvalidSyntax("invalid variable name: '\{name}'")
      }
      for char in name {
        if !is_name_char(char) {
          raise InvalidSyntax("invalid variable name: '\{name}'")
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
fn io_number(chars : Array[Char], start : Int32) -> (Int32, Int32)? {
  let mut end = start
  while end < chars.length() && chars[end] is ('0'..<='9') {
    end += 1
  }
  if end == start || !(chars.get(end) is Some('<' | '>')) {
    return None
  }
  let descriptor = @string.parse_int(String::from_array(chars[start:end])) catch {
    _ => -1
  }
  Some((descriptor, end))
}

///|
fn lex_input(
  script : String,
  fragment~ : Bool = false,
) -> Array[Token] raise ParseIssue {
  let chars : Array[Char] = script.iter().collect()
  let tokens : Array[Token] = []
  let heredocs : Array[PendingHereDoc] = []
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
          flush_literal(parts, literal, quoted=true)
          quote = None
        } else {
          literal.write_char(char)
        }
        i += 1
      }
      Some('"') =>
        if char == '"' {
          flush_literal(parts, literal, quoted=true)
          quote = None
          i += 1
        } else if char == '\\' {
          if i + 1 >= chars.length() {
            raise IncompleteSyntax("unterminated escape in double quote")
          }
          let next = chars[i + 1]
          if next == '\n' {
            i += 2
          } else if next == '$' || next == '"' || next == '\\' || next == '`' {
            literal.write_char(next)
            i += 2
          } else {
            literal.write_char('\\')
            literal.write_char(next)
            i += 2
          }
        } else if char == '$' {
          flush_literal(parts, literal, quoted=true)
          let (part, next) = parse_dollar_input(chars, i, true)
          match part {
            Some(value) => parts.push(value)
            None => literal.write_char('$')
          }
          i = next
        } else if char == '`' {
          flush_literal(parts, literal, quoted=true)
          let (part, next) = parse_backtick_input(chars, i, true)
          parts.push(part)
          i = next
        } else {
          literal.write_char(char)
          i += 1
        }
      Some(_) => raise InvalidSyntax("invalid internal quote state")
      None =>
        if fragment &&
          (
            is_shell_space(char) ||
            char is ('\n' | ';' | '&' | '|' | '<' | '>' | '(' | ')' | '{' | '}')
          ) {
          literal.write_char(char)
          started = true
          i += 1
        } else if is_shell_space(char) {
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
          } else {
            if tokens.last() != Some(Sequence) {
              tokens.push(Sequence)
            }
            i += 1
            if char == '\n' && !heredocs.is_empty() {
              i = consume_heredocs(chars, i, heredocs, tokens)
            }
          }
        } else if char == '#' && !started {
          while i < chars.length() && chars[i] != '\n' {
            i += 1
          }
        } else if char == '\'' || char == '"' {
          flush_literal(parts, literal)
          quote = Some(char)
          started = true
          preserve_empty = true
          i += 1
        } else if char == '\\' {
          if i + 1 >= chars.length() {
            raise IncompleteSyntax("script ends with an unmatched backslash")
          }
          if chars[i + 1] == '\n' {
            i += 2
          } else {
            flush_literal(parts, literal)
            parts.push(QuotedText(chars[i + 1].to_string()))
            started = true
            i += 2
          }
        } else if char == '$' {
          flush_literal(parts, literal)
          let (part, next) = parse_dollar_input(chars, i, false)
          match part {
            Some(value) => parts.push(value)
            None => literal.write_char('$')
          }
          started = true
          i = next
        } else if char == '`' {
          flush_literal(parts, literal)
          let (part, next) = parse_backtick_input(chars, i, false)
          parts.push(part)
          started = true
          i = next
        } else if char == '&' {
          push_word(tokens, parts, literal, started, preserve_empty)
          started = false
          preserve_empty = false
          if i + 1 < chars.length() && chars[i + 1] == '&' {
            tokens.push(AndIf)
            i += 2
          } else {
            raise InvalidSyntax("background execution is not supported")
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
          io_number(chars, i) is Some((descriptor, operator_at)) {
          if descriptor < 0 || descriptor > 2 {
            raise InvalidSyntax(
              "additional descriptors require a public child descriptor API",
            )
          }
          let input = chars[operator_at] == '<'
          if chars.get(operator_at + 1) == Some('&') {
            tokens.push(RedirectCopy(descriptor))
            i = operator_at + 2
          } else if (input && descriptor == 0) || (!input && descriptor == 1) {
            i = operator_at
          } else if !input && descriptor == 2 {
            if chars.get(operator_at + 1) == Some('>') {
              tokens.push(RedirectErrorAppend)
              i = operator_at + 2
            } else {
              tokens.push(RedirectError)
              i = operator_at + 1
            }
          } else {
            raise InvalidSyntax(
              "changing a standard descriptor's access direction requires a public child descriptor API",
            )
          }
        } else if char == '>' || char == '<' {
          push_word(tokens, parts, literal, started, preserve_empty)
          started = false
          preserve_empty = false
          if chars.get(i + 1) == Some('&') {
            tokens.push(RedirectCopy(if char == '<' { 0 } else { 1 }))
            i += 2
            continue
          }
          if char == '<' {
            if i + 1 < chars.length() && chars[i + 1] == '<' {
              let strip_tabs = chars.get(i + 2) == Some('-')
              let (delimiter, expand, next) = heredoc_delimiter(
                chars,
                i + (if strip_tabs { 3 } else { 2 }),
              )
              heredocs.push({
                delimiter,
                expand,
                strip_tabs,
                token_index: tokens.length(),
              })
              tokens.push(RedirectHereDoc("", expand))
              i = next
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
    raise IncompleteSyntax("unterminated quote")
  }
  if !heredocs.is_empty() {
    raise IncompleteSyntax("unterminated here-document")
  }
  push_word(tokens, parts, literal, started, preserve_empty)
  while tokens.last() == Some(Sequence) {
    ignore(tokens.pop())
  }
  tokens
}

///|
fn lex(
  script : String,
  fragment~ : Bool = false,
) -> Array[Token] raise ShellError {
  lex_input(script, fragment~) catch {
    issue => raise issue.shell_error()
  }
}

///|
fn parse_dollar(
  chars : Array[Char],
  index : Int32,
  quoted : Bool,
) -> (WordPart?, Int32) raise ShellError {
  parse_dollar_input(chars, index, quoted) catch {
    issue => raise issue.shell_error()
  }
}
