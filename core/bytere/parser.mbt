///|
#derive(Eq, Hash)
priv enum Assertion {
  Begin
  End
  LineBegin
  LineEnd
  WordBegin
  WordEnd
  WordBoundary
  NotWordBoundary
}

///|
priv enum Tree {
  Empty
  Literal(Int32)
  Any
  Class(Array[Bool])
  Assert(Assertion)
  Sequence(Array[Tree])
  Choice(Array[Tree])
  Repeat(Tree, Int32, Int32?)
  Capture(Int32, Tree)
  Reference(Int32)
}

///|
priv struct Parser {
  scalar_sets : Array[ScalarSet]?
  source : String
  extended : Bool
  emacs : Bool
  grep_syntax : Bool
  ignore_case : Bool
  mut index : Int32
  closed : Array[Bool]
  mut backreferences : Bool
  mut depth : Int32
}

///|
fn Parser::code(self : Parser, index : Int32) -> Int32 {
  self.source[index].to_int()
}

///|
fn Parser::operator(self : Parser, code : Int32) -> Bool {
  if self.emacs && (code == 123 || code == 125) {
    return false
  }
  self.index < self.source.length() &&
  (if self.extended || code == 42 || (self.emacs && (code == 43 || code == 63)) {
    self.code(self.index) == code
  } else {
    self.code(self.index) == 92 &&
    self.index + 1 < self.source.length() &&
    self.code(self.index + 1) == code
  })
}

///|
fn Parser::take(self : Parser, code : Int32) -> Bool {
  if !self.operator(code) {
    return false
  }
  self.index += if self.extended ||
    code == 42 ||
    (self.emacs && (code == 43 || code == 63)) {
    1
  } else {
    2
  }
  true
}

///|
fn Parser::expression(self : Parser) -> Tree raise PatternError {
  let branches = [self.sequence()]
  while self.take(124) {
    branches.push(self.sequence())
  }
  if branches.length() == 1 {
    branches[0]
  } else {
    Choice(branches)
  }
}

///|
fn Parser::sequence(self : Parser) -> Tree raise PatternError {
  let parts : Array[Tree] = []
  while self.index < self.source.length() &&
        !self.operator(124) &&
        !(self.operator(41) &&
        (!self.extended || !self.grep_syntax || self.depth > 0)) {
    let mut item = self.atom(parts.is_empty())
    while true {
      if self.take(42) {
        item = Repeat(item, 0, None)
      } else if self.take(43) {
        item = Repeat(item, 1, None)
      } else if self.take(63) {
        item = Repeat(item, 0, Some(1))
      } else if self.operator(123) {
        let saved = self.index
        ignore(self.take(123))
        if self.interval() is Some((minimum, maximum)) {
          item = Repeat(item, minimum, maximum)
        } else if self.grep_syntax && self.extended {
          self.index = saved
          break
        } else {
          raise PatternError("invalid repetition interval")
        }
      } else {
        break
      }
    }
    parts.push(item)
  }
  match parts.length() {
    0 => Empty
    1 => parts[0]
    _ => Sequence(parts)
  }
}

///|
fn Parser::number(self : Parser) -> Int32? raise PatternError {
  let begin = self.index
  let mut value = 0
  while self.index < self.source.length() &&
        self.code(self.index) >= 48 &&
        self.code(self.index) <= 57 {
    value = value * 10 + self.code(self.index) - 48
    // GNU regex.h defines RE_DUP_MAX as 32767. This is a syntax limit,
    // not a limit on the number of matching steps.
    if value > 32767 {
      raise PatternError("repetition interval exceeds 32767")
    }
    self.index += 1
  }
  if self.index == begin {
    None
  } else {
    Some(value)
  }
}

///|
fn Parser::interval(self : Parser) -> (Int32, Int32?)? raise PatternError {
  let first = self.number()
  let comma = self.index < self.source.length() && self.code(self.index) == 44
  if first is None && !comma {
    if self.operator(125) {
      raise PatternError("empty repetition interval")
    }
    return None
  }
  let minimum = first.unwrap_or(0)
  let maximum = if comma {
    self.index += 1
    self.number()
  } else {
    Some(minimum)
  }
  if !self.take(125) {
    return None
  }
  if maximum is Some(limit) && limit < minimum {
    raise PatternError("reversed repetition interval")
  }
  Some((minimum, maximum))
}

///|
fn Parser::atom(self : Parser, first : Bool) -> Tree raise PatternError {
  if self.take(40) {
    let group = self.closed.length()
    self.closed.push(false)
    self.depth += 1
    let inner = self.expression()
    guard self.take(41) else {
      raise PatternError("unmatched opening parenthesis")
    }
    self.depth -= 1
    self.closed[group] = true
    return Capture(group, inner)
  }
  let c = self.next_code()
  match c {
    46 => if self.emacs { Class(Array::makei(256, c => c != 10)) } else { Any }
    91 => self.bracket()
    94 if self.extended || first =>
      Assert(if self.emacs { LineBegin } else { Begin })
    36 if self.extended ||
      self.index == self.source.length() ||
      self.operator(124) ||
      self.operator(41) => Assert(if self.emacs { LineEnd } else { End })
    92 => {
      guard self.index < self.source.length() else {
        raise PatternError("trailing backslash in regular expression")
      }
      let escaped = self.next_code()
      match escaped {
        49..<=57 => {
          let group = escaped - 49
          guard group < self.closed.length() && self.closed[group] else {
            raise PatternError("invalid backreference")
          }
          self.backreferences = true
          Reference(group)
        }
        60 => Assert(WordBegin)
        62 => Assert(WordEnd)
        98 => Assert(WordBoundary)
        66 => Assert(NotWordBoundary)
        96 => Assert(Begin)
        39 => Assert(End)
        119 => self.make_class([Named("word")], false)
        87 => self.make_class([Named("word")], true)
        115 => self.make_class([Named("space")], false)
        83 => self.make_class([Named("space")], true)
        43 | 63 | 123 if !self.extended && !self.emacs =>
          raise PatternError("repetition operator has no preceding expression")
        _ => self.literal(escaped)
      }
    }
    42 if !self.extended && first => self.literal(c)
    42 | 43 | 63 if self.extended =>
      raise PatternError("repetition operator has no preceding expression")
    123 if self.extended && !self.grep_syntax =>
      raise PatternError("repetition operator has no preceding expression")
    _ => {
      guard self.scalar_sets is Some(_) || c <= 255 else {
        raise PatternError("regular expression requires a byte string")
      }
      self.literal(c)
    }
  }
}

///|
fn Parser::literal(self : Parser, code : Int32) -> Tree {
  if self.scalar_sets is Some(sets) {
    let c = code.unsafe_to_char()
    sets.push(ScalarSet::new([Range(c, c)], self.ignore_case, false))
    return Literal(sets.length() - 1)
  }
  if self.ignore_case &&
    ((code >= 65 && code <= 90) || (code >= 97 && code <= 122)) {
    let lower = ascii_fold(code)
    Class(Array::makei(256, c => c == lower || c == lower - 32))
  } else {
    Literal(code)
  }
}

///|
fn ascii_fold(code : Int32) -> Int32 {
  if code >= 65 && code <= 90 {
    code + 32
  } else {
    code
  }
}

///|
fn byte_class(name : String) -> Array[Bool] raise PatternError {
  guard name
    is ("alnum"
    | "alpha"
    | "blank"
    | "cntrl"
    | "digit"
    | "graph"
    | "lower"
    | "print"
    | "punct"
    | "space"
    | "upper"
    | "xdigit"
    | "word") else {
    raise PatternError("invalid character class name")
  }
  Array::makei(256, c => {
    let alpha = (c >= 65 && c <= 90) || (c >= 97 && c <= 122)
    let digit = c >= 48 && c <= 57
    match name {
      "alnum" => alpha || digit
      "alpha" => alpha
      "blank" => c == 9 || c == 32
      "cntrl" => c < 32 || c == 127
      "digit" => digit
      "graph" => c >= 33 && c <= 126
      "lower" => c >= 97 && c <= 122
      "print" => c >= 32 && c <= 126
      "punct" => c >= 33 && c <= 126 && !alpha && !digit
      "space" => c == 32 || (c >= 9 && c <= 13)
      "upper" => c >= 65 && c <= 90
      "xdigit" => digit || (c >= 65 && c <= 70) || (c >= 97 && c <= 102)
      _ => alpha || digit || c == 95
    }
  })
}

///|
fn Parser::next_code(self : Parser) -> Int32 {
  let c = self.source.get_char(self.index).unwrap()
  self.index += c.utf16_len()
  c.to_int()
}

///|
fn Parser::bracket_item(self : Parser) -> ScalarTerm raise PatternError {
  let c = self.next_code()
  if !self.emacs &&
    c == 91 &&
    self.index < self.source.length() &&
    self.code(self.index) is (58 | 46 | 61) {
    let marker = self.next_code()
    let begin = self.index
    while self.index + 1 < self.source.length() &&
          !(self.code(self.index) == marker && self.code(self.index + 1) == 93) {
      self.index += 1
    }
    guard self.index + 1 < self.source.length() else {
      raise PatternError("unterminated bracket element")
    }
    let name = self.source[begin:self.index]
    self.index += 2
    if marker == 58 {
      guard name
        is ("alnum"
        | "alpha"
        | "blank"
        | "cntrl"
        | "digit"
        | "graph"
        | "lower"
        | "print"
        | "punct"
        | "space"
        | "upper"
        | "xdigit"
        | "word") else {
        raise PatternError("invalid character class name")
      }
      return Named(name.to_owned())
    }
    guard name.iter().next() is Some(ch) &&
      name.length() == ch.utf16_len() &&
      (self.scalar_sets is Some(_) || ch.to_int() <= 255) else {
      raise PatternError("invalid C-locale collating element")
    }
    if self.scalar_sets is Some(_) && !ch.is_ascii() {
      raise PatternError("Invalid collation character")
    }
    return Range(ch, ch)
  }
  guard self.scalar_sets is Some(_) || c <= 255 else {
    raise PatternError("regular expression requires a byte string")
  }
  let ch = c.unsafe_to_char()
  Range(ch, ch)
}

///|
fn Parser::make_class(
  self : Parser,
  terms : Array[ScalarTerm],
  negated : Bool,
) -> Tree raise PatternError {
  if self.scalar_sets is Some(sets) {
    sets.push(ScalarSet::new(terms, self.ignore_case, negated))
    return Literal(sets.length() - 1)
  }
  let members = Array::make(256, false)
  for term in terms {
    match term {
      Range(a, b) =>
        for c in a.to_int()..<=b.to_int() {
          members[c] = true
        }
      Named(name) => {
        let class = byte_class(name)
        for i in 0..<256 {
          members[i] = members[i] || class[i]
        }
      }
    }
  }
  if self.ignore_case {
    for upper in 65..<=90 {
      let present = members[upper] || members[upper + 32]
      members[upper] = present
      members[upper + 32] = present
    }
  }
  Class(if negated { members.map(x => !x) } else { members })
}

///|
fn Parser::bracket(self : Parser) -> Tree raise PatternError {
  let negated = self.index < self.source.length() && self.code(self.index) == 94
  if negated {
    self.index += 1
  }
  let terms = []
  while self.index < self.source.length() {
    if self.code(self.index) == 93 && !terms.is_empty() {
      self.index += 1
      return self.make_class(terms, negated)
    }
    let item = self.bracket_item()
    if self.index + 1 < self.source.length() &&
      self.code(self.index) == 45 &&
      self.code(self.index + 1) != 93 {
      self.index += 1
      let right = self.bracket_item()
      guard item is Range(a, _) &&
        right is Range(b, _) &&
        (a <= b || self.emacs) else {
        raise PatternError("invalid bracket range")
      }
      if self.scalar_sets is Some(_) && (!a.is_ascii() || !b.is_ascii()) {
        raise PatternError("Invalid collation character")
      }
      terms.push(Range(a, b))
    } else {
      terms.push(item)
    }
  }
  raise PatternError("unterminated bracket expression")
}

///|
priv enum Instruction {
  Accept
  Byte(Int32, Int32)
  Any(Int32)
  Class(Array[Bool], Int32)
  Assert(Assertion, Int32)
  Split(Int32, Int32)
  Save(Int32, Int32)
  Reference(Int32, Int32)
  SaveOptional(Int32, Int32)
}

///|
fn Tree::emit(
  self : Tree,
  program : Array[Instruction],
  next : Int32,
  optional~ : Bool = false,
  cloned~ : Bool = false,
) -> Int32 {
  match self {
    Empty => next
    Sequence(parts) => {
      let mut entry = next
      for i = parts.length() - 1; i >= 0; i = i - 1 {
        entry = parts[i].emit(program, entry, cloned~)
      }
      entry
    }
    Choice(branches) => {
      let mut entry = branches[branches.length() - 1].emit(
        program,
        next,
        cloned~,
      )
      for i = branches.length() - 2; i >= 0; i = i - 1 {
        let left = branches[i].emit(program, next, cloned~)
        program.push(Split(left, entry))
        entry = program.length() - 1
      }
      entry
    }
    Repeat(inner, minimum, maximum) => {
      // GNU regcomp.c's duplicate_tree clears optional-subexpression marks in
      // each clone. Preserve nested marks only in the original first copy;
      // a new optional tail may mark its own root capture after cloning.
      let mut entry = next
      match maximum {
        None => {
          let split = program.length()
          program.push(Accept)
          let body = inner.emit(
            program,
            split,
            optional=!cloned,
            cloned=cloned || minimum > 0,
          )
          program[split] = Split(body, next)
          entry = split
        }
        Some(limit) => {
          let bodies : Array[Int32] = []
          for index = limit - minimum - 1; index >= 0; index = index - 1 {
            let body = inner.emit(
              program,
              entry,
              optional=!cloned && index == 0,
              cloned=cloned || minimum > 0 || index > 0,
            )
            bodies.push(body)
            entry = body
          }
          for index = bodies.length() - 1; index >= 0; index = index - 1 {
            let skip = if index == 0 { next } else { bodies[index - 1] }
            program.push(Split(entry, skip))
            entry = program.length() - 1
          }
        }
      }
      for index = minimum - 1; index >= 0; index = index - 1 {
        entry = inner.emit(program, entry, cloned=cloned || index > 0)
      }
      entry
    }
    Capture(group, inner) => {
      program.push(
        if optional {
          SaveOptional(group, next)
        } else {
          Save(group * 2 + 1, next)
        },
      )
      let body = inner.emit(program, program.length() - 1, cloned~)
      program.push(Save(group * 2, body))
      program.length() - 1
    }
    _ => {
      program.push(
        match self {
          Literal(c) => Byte(c, next)
          Any => Any(next)
          Class(members) => Class(members, next)
          Assert(assertion) => Assert(assertion, next)
          Reference(group) => Reference(group, next)
          _ => abort("unreachable regex instruction")
        },
      )
      program.length() - 1
    }
  }
}

///|
fn Tree::is_literal(self : Tree) -> Bool {
  match self {
    Empty | Literal(_) => true
    Sequence(parts) => parts.all(part => part.is_literal())
    _ => false
  }
}

///|
fn Tree::literal_pattern(self : Tree) -> LiteralPattern? {
  let parts = match self {
    Sequence(parts) => parts
    _ => [self]
  }
  let begin = parts[0] is Assert(Begin)
  let end = parts[parts.length() - 1] is Assert(End)
  let text = StringBuilder()
  let left = if begin { 1 } else { 0 }
  let right = parts.length() - (if end { 1 } else { 0 })
  for index in left..<right {
    let part = parts[index]
    guard part.is_literal() else { return None }
    ignore(part.literal_prefix(text))
  }
  Some({ text: text.to_string(), begin, end, })
}

///|
fn Tree::literal_prefix(self : Tree, out : StringBuilder) -> Bool {
  match self {
    Empty => true
    Literal(c) => {
      out.write_char(c.unsafe_to_char())
      true
    }
    Capture(_, inner) => inner.literal_prefix(out)
    Sequence(parts) => {
      for part in parts {
        if !part.literal_prefix(out) {
          return false
        }
      }
      true
    }
    _ => false
  }
}
