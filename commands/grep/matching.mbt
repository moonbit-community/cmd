///|
/// Translate the BRE/ERE operator spelling to the public MoonBit regex API.
/// Backreferences have no faithful implementation in that API and are rejected.
fn translate_regexp(
  pattern : String,
  extended : Bool,
) -> String raise GrepError {
  let chars : Array[Char] = pattern.iter().collect()
  let output = StringBuilder()
  let mut index = 0
  let mut bracket = false
  while index < chars.length() {
    let char = chars[index]
    if char == '\\' && !bracket {
      index += 1
      if index == chars.length() {
        raise GrepError("trailing backslash")
      }
      let escaped = chars[index]
      if escaped is ('1'..='9') {
        raise GrepError(
          "backreferences are not supported by the public regex API",
        )
      }
      if escaped is ('(' | ')' | '{' | '}' | '+' | '?' | '|') {
        if extended {
          output.write_char('\\')
        }
        output.write_char(escaped)
      } else if escaped is ('w' | 'W' | 's' | 'S') {
        output.write_string(
          match escaped {
            'w' => "[A-Za-z0-9_]"
            'W' => "[^A-Za-z0-9_]"
            's' => "[[:space:]]"
            _ => "[^[:space:]]"
          },
        )
      } else if escaped is ('<' | '>') {
        raise GrepError(
          "directional word assertions are not supported by the public regex API",
        )
      } else if escaped is ('b' | 'B') {
        output.write_char('\\')
        output.write_char(escaped)
      } else {
        // A backslash before an ordinary character is not a PCRE escape.
        if escaped is ('.' | '[' | ']' | '*' | '^' | '$' | '\\') {
          output.write_char('\\')
        }
        output.write_char(escaped)
      }
    } else {
      if !bracket &&
        !extended &&
        char is ('(' | ')' | '{' | '}' | '+' | '?' | '|') {
        output.write_char('\\')
      }
      output.write_char(char)
      if char == '[' {
        bracket = true
      } else if char == ']' {
        bracket = false
      }
    }
    index += 1
  }
  output.to_string()
}

///|
fn match_boundaries(
  line : String,
  start : Int,
  end : Int,
  whole : Bool,
  word : Bool,
) -> Bool {
  (!whole || (start == 0 && end == line.length())) &&
  (
    !word ||
    (
      (start == 0 || !is_word_char(line[start - 1].to_int().unsafe_to_char())) &&
      (
        end == line.length() ||
        !is_word_char(line[end].to_int().unsafe_to_char())
      )
    )
  )
}

///|
/// Choose the earliest start and then the longest match at that start.
/// Testing an exact prefix and suffix against the complete record preserves
/// anchors and word assertions, including when -o resumes partway through it.
fn Matcher::next_match(
  self : Matcher,
  line : String,
  position : Int,
) -> (Int, Int)? {
  if position > line.length() {
    return None
  }
  match self {
    Fixed(patterns, whole, word) => {
      for start in position..<=line.length() {
        let mut longest = -1
        for pattern in patterns {
          let end = start + pattern.length()
          if end <= line.length() &&
            line[start:end] == pattern &&
            match_boundaries(line, start, end, whole, word) &&
            end > longest {
            longest = end
          }
        }
        if longest >= 0 {
          return Some((start, longest))
        }
      }
      None
    }
    Regular(None, _, _) => None
    Regular(Some(regex), whole, word) => {
      let mut search = position
      while search <= line.length() {
        guard regex.execute(line, last_index=search) is Some(candidate) else {
          return None
        }
        let start = candidate.before().length()
        let prefix = Regex::string(line[:start])
        let mut end = line.length()
        while end >= start {
          if match_boundaries(line, start, end, whole, word) {
            let bounded = (try! Regex("^")) +
              prefix +
              regex +
              Regex::string(line[end:]) +
              (try! Regex("$"))
            if bounded.execute(line) is Some(_) {
              return Some((start, end))
            }
          }
          end -= 1
        }
        search = start + 1
      }
      None
    }
  }
}
