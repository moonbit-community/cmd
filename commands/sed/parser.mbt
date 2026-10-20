///|
priv suberror SedError {
  SedError(String)
}

///|
fn[T] fail(message : String) -> T raise SedError {
  raise SedError(message)
}

///|
enum PatternRef {
  Explicit(@bytere.Pattern)
  Previous
}

///|
enum Address {
  Number(Int32)
  Last
  Search(PatternRef)
}

///|
enum Action {
  Print
  Delete
  Quit
  Number
  Substitute(PatternRef, String, Bool, Int32, Bool)
}

///|
struct Command {
  first : Address?
  last : Address?
  invert : Bool
  action : Action
  mut inside : Bool
}

///|
struct Script {
  source : String
  extended : Bool
  mut index : Int32
}

///|
fn Script::blanks(self : Script) -> Unit {
  while self.index < self.source.length() &&
        self.source[self.index] is (' ' | '\t' | '\r') {
    self.index += 1
  }
}

///|
fn Script::delimited(self : Script, delimiter : UInt16) -> String raise {
  let result = StringBuilder()
  while self.index < self.source.length() {
    let c = self.source[self.index]
    self.index += 1
    if c == delimiter {
      return result.to_string()
    }
    if c == '\\' {
      guard self.index < self.source.length() else {
        fail("unterminated escape")
      }
      let next = self.source[self.index]
      self.index += 1
      result.write_char('\\')
      result.write_char(next.to_int().unsafe_to_char())
    } else {
      result.write_char(c.to_int().unsafe_to_char())
    }
  }
  fail("unterminated delimited expression")
}

///|
fn Script::pattern(self : Script, source : String) -> PatternRef raise {
  if source == "" {
    return Previous
  }
  let re = @bytere.compile(source, extended=self.extended)
  Explicit(re)
}

///|
fn Script::address(self : Script) -> Address? raise {
  self.blanks()
  if self.index == self.source.length() {
    return None
  }
  let c = self.source[self.index]
  if c == '$' {
    self.index += 1
    return Some(Last)
  }
  if c == '/' {
    self.index += 1
    return Some(Search(self.pattern(self.delimited('/'))))
  }
  if c >= '0' && c <= '9' {
    let start = self.index
    while self.index < self.source.length() &&
          self.source[self.index] >= '0' &&
          self.source[self.index] <= '9' {
      self.index += 1
    }
    let number = @string.parse_int(self.source[start:self.index])
    guard number > 0 else { fail("zero address is not supported") }
    return Some(Number(number))
  }
  None
}

///|
fn compile(source : String, extended : Bool) -> Array[Command] raise {
  let parser : Script = { source, extended, index: 0, }
  let commands : Array[Command] = []
  while parser.index < source.length() {
    parser.blanks()
    if parser.index == source.length() {
      break
    }
    if source[parser.index] is (';' | '\n') {
      parser.index += 1
      continue
    }
    if source[parser.index] == '#' {
      while parser.index < source.length() && source[parser.index] != '\n' {
        parser.index += 1
      }
      continue
    }
    let first = parser.address()
    parser.blanks()
    let last = if parser.index < source.length() && source[parser.index] == ',' {
      parser.index += 1
      let address = parser.address()
      guard address is Some(_) else { fail("missing range end") }
      address
    } else {
      None
    }
    parser.blanks()
    let invert = parser.index < source.length() && source[parser.index] == '!'
    if invert {
      parser.index += 1
      parser.blanks()
    }
    guard parser.index < source.length() else { fail("missing command") }
    let code = source[parser.index]
    parser.index += 1
    let action = match code {
      'p' => Print
      'd' => Delete
      'q' => {
        if last is Some(_) {
          fail("q accepts one address")
        }
        Quit
      }
      '=' => Number
      's' => {
        guard parser.index < source.length() else {
          fail("missing substitution delimiter")
        }
        let delimiter = source[parser.index]
        if delimiter == '\\' || delimiter == '\n' {
          fail("invalid substitution delimiter")
        }
        parser.index += 1
        let re = parser.pattern(parser.delimited(delimiter))
        let replacement = parser.delimited(delimiter)
        // Validate captures before any input is consumed.
        let mut r = 0
        while r < replacement.length() {
          if replacement[r] == '\\' && r + 1 < replacement.length() {
            r += 1
            if re is Explicit(pattern) &&
              replacement[r] >= '1' &&
              replacement[r] <= '9' &&
              replacement[r].to_int() - 48 > pattern.group_count() {
              fail("invalid replacement backreference")
            }
          }
          r += 1
        }
        let mut global = false
        let mut print = false
        let mut occurrence = 0
        while parser.index < source.length() &&
              !(source[parser.index] is (';' | '\n' | ' ' | '\t' | '\r')) {
          let flag = source[parser.index]
          parser.index += 1
          match flag {
            'g' => {
              guard !global else { fail("duplicate g flag") }
              global = true
            }
            'p' => print = true
            '1'..<='9' => {
              guard occurrence == 0 else { fail("duplicate occurrence flag") }
              let begin = parser.index - 1
              while parser.index < source.length() &&
                    source[parser.index] >= '0' &&
                    source[parser.index] <= '9' {
                parser.index += 1
              }
              occurrence = @string.parse_int(source[begin:parser.index])
            }
            _ => fail("unsupported substitution flag")
          }
        }
        Substitute(re, replacement, global, occurrence, print)
      }
      _ =>
        fail(
          "unsupported sed command: " +
          code.to_int().unsafe_to_char().to_string(),
        )
    }
    parser.blanks()
    if parser.index < source.length() &&
      !(source[parser.index] is (';' | '\n' | '#')) {
      fail("extra characters after command")
    }
    commands.push({ first, last, invert, action, inside: false, })
  }
  commands
}
