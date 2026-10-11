///|
pub(all) suberror PatternError {
  PatternError(String)
}

///|
/// A reversible one-code-unit-per-byte view for C-locale text algorithms.
pub fn text(data : BytesView) -> String {
  let out = StringBuilder()
  for b in data {
    out.write_char(b.to_int().unsafe_to_char())
  }
  out.to_string()
}

///|
pub fn bytes(value : StringView) -> Bytes {
  Bytes::from_array(value.iter().map(c => c.to_int().to_byte()).collect())
}

///|
pub fn argument(value : String) -> String {
  text(@utf8.encode(value))
}

///|
pub struct Pattern {
  regex : Regex
  groups : Int
}

///|
pub(all) struct Hit {
  start : Int
  end : Int
  groups : Array[String?]
}

///|
/// Compile the regular BRE/ERE subset. Backreferences and non-POSIX engine
/// extensions are rejected instead of silently changing their meaning.
pub fn compile(pattern : String, extended? : Bool = false) -> Pattern raise {
  let out = StringBuilder()
  let mut i = 0
  let mut bracket = false
  let mut groups = 0
  while i < pattern.length() {
    let c = pattern[i].to_int().unsafe_to_char()
    if c == '\\' && !bracket {
      i += 1
      guard i < pattern.length() else {
        raise PatternError("trailing backslash in regular expression")
      }
      let e = pattern[i].to_int().unsafe_to_char()
      if e is ('1'..='9' | '<' | '>' | 'b' | 'B') {
        raise PatternError(
          "backreferences and word assertions are not supported",
        )
      }
      if e is ('(' | ')' | '{' | '}' | '+' | '?' | '|') {
        if extended {
          out.write_char('\\')
        }
        if !extended && e == '(' {
          groups += 1
        }
        out.write_char(e)
      } else if e == 'n' {
        out.write_char('\n')
      } else {
        if e is ('.' | '[' | ']' | '*' | '^' | '$' | '\\') {
          out.write_char('\\')
        }
        out.write_char(e)
      }
    } else {
      if !bracket && extended && c == '(' {
        if i + 1 < pattern.length() && pattern[i + 1] == '?' {
          raise PatternError("regex engine extensions are not supported")
        }
        groups += 1
      }
      if !bracket && !extended && c is ('(' | ')' | '{' | '}' | '+' | '?' | '|') {
        out.write_char('\\')
      }
      out.write_char(c)
      if c == '[' {
        bracket = true
      } else if c == ']' {
        bracket = false
      }
    }
    i += 1
  }
  let translated = out.to_string()
  { regex: Regex(translated), groups, }
}

///|
pub fn Pattern::group_count(self : Pattern) -> Int {
  self.groups
}

///|
/// Choose the earliest start, then longest match, retaining captures.
pub fn Pattern::find(self : Pattern, value : String, start? : Int = 0) -> Hit? {
  if start > value.length() {
    return None
  }
  guard self.regex.execute(value, last_index=start) is Some(first) else {
    return None
  }
  let left = first.before().length()
  let prefix = (try! Regex("^")) + Regex::string(value[:left])
  for right = value.length(); right >= left; right = right - 1 {
    let bounded = prefix +
      self.regex +
      Regex::string(value[right:]) +
      (try! Regex("$"))
    if bounded.execute(value) is Some(hit) {
      let groups : Array[String?] = [Some(value[left:right].to_owned())]
      for group in 1..<=self.groups {
        groups.push(hit.group(group).map(v => v.to_owned()))
      }
      return Some({ start: left, end: right, groups, })
    }
  }
  None
}
