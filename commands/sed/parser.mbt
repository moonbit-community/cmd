///|
priv suberror SedError {
  SedError(String)
}

///|
priv suberror SedLabelError {
  SedLabelError(String)
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
  HoldCopy
  HoldAppend
  Get
  GetAppend
  Exchange
  Label
  Jump(Int32)
  TestJump(Int32, Bool)
  Group(Int32)
  EndGroup
  Next
  Join
  PrintFirst
  DeleteFirst
  Append(String)
  Insert(String)
  Change(String)
}

///|
struct Command {
  first : Address?
  last : Address?
  invert : Bool
  mut action : Action
  mut inside : Bool
  mut closed : Bool
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
  let normalized = StringBuilder()
  let mut index = 0
  while index < source.length() {
    if source[index] == '\\' && index + 1 < source.length() {
      if source[index + 1] == 'n' {
        normalized.write_char('\n')
      } else {
        normalized.write_char('\\')
        normalized.write_char(source[index + 1].to_int().unsafe_to_char())
      }
      index += 2
    } else {
      normalized.write_char(source[index].to_int().unsafe_to_char())
      index += 1
    }
  }
  let re = @bytere.compile(normalized.to_string(), extended=self.extended)
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
fn Script::label(self : Script) -> String {
  self.blanks()
  let begin = self.index
  while self.index < self.source.length() &&
        !(self.source[self.index]
        is (';' | '\n' | '}' | '#' | ' ' | '\t' | '\r')) {
    self.index += 1
  }
  self.source[begin:self.index].to_owned()
}

///|
fn Script::text(self : Script) -> String raise {
  self.blanks()
  guard self.index < self.source.length() else {
    fail("expected text after command")
  }
  if self.source[self.index] == '\\' {
    self.index += 1
    if self.index == self.source.length() {
      return ""
    }
    if self.source[self.index] == '\n' {
      self.index += 1
    }
  }
  let result = StringBuilder()
  while self.index < self.source.length() {
    let c = self.source[self.index]
    self.index += 1
    if c == '\n' {
      break
    }
    if c == '\\' && self.index == self.source.length() {
      break
    }
    if c == '\\' && self.index < self.source.length() {
      let next = self.source[self.index]
      self.index += 1
      result.write_char(
        match next {
          'n' => '\n'
          't' => '\t'
          'r' => '\r'
          _ => next.to_int().unsafe_to_char()
        },
      )
    } else {
      result.write_char(c.to_int().unsafe_to_char())
    }
  }
  result.write_char('\n')
  result.to_string()
}

///|
fn compile(source : String, extended : Bool) -> Array[Command] raise {
  let parser : Script = { source, extended, index: 0, }
  let commands : Array[Command] = []
  let labels : Map[String, Int32] = Map([])
  let jumps : Array[(Int32, String)] = []
  let groups : Array[Int32] = []
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
      'h' => HoldCopy
      'H' => HoldAppend
      'g' => Get
      'G' => GetAppend
      'x' => Exchange
      'n' => Next
      'N' => Join
      'P' => PrintFirst
      'D' => DeleteFirst
      ':' => {
        guard first is None else { fail(": accepts no addresses") }
        let label = parser.label()
        guard label != "" else { fail("\":\" lacks a label") }
        labels[label] = commands.length()
        Label
      }
      'b' | 't' | 'T' => {
        jumps.push((commands.length(), parser.label()))
        if code == 'b' {
          Jump(0)
        } else {
          TestJump(0, code == 't')
        }
      }
      '{' => {
        groups.push(commands.length())
        Group(0)
      }
      '}' => {
        guard first is None && !invert else { fail("} accepts no addresses") }
        guard groups.pop() is Some(open) else { fail("unexpected `}'") }
        commands[open].action = Group(commands.length() + 1)
        EndGroup
      }
      'a' => Append(parser.text())
      'i' => Insert(parser.text())
      'c' => Change(parser.text())
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
              !(source[parser.index] is (';' | '\n' | '}' | ' ' | '\t' | '\r')) {
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
    if !(code is ('{' | '}' | 'a' | 'i' | 'c')) {
      parser.blanks()
      if parser.index < source.length() &&
        !(source[parser.index] is (';' | '\n' | '#' | '}')) {
        fail("extra characters after command")
      }
    }
    commands.push({ first, last, invert, action, inside: false, closed: false, })
  }
  guard groups.is_empty() else { fail("unmatched `{'") }
  for (index, name) in jumps {
    let target = if name == "" {
      commands.length()
    } else {
      guard labels.get(name) is Some(target) else {
        raise SedLabelError("can't find label for jump to `" + name + "'")
      }
      target
    }
    commands[index].action = match commands[index].action {
      TestJump(_, positive) => TestJump(target, positive)
      _ => Jump(target)
    }
  }
  commands
}
