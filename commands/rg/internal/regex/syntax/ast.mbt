///|
/// A single position in a regular expression. `offset` is a character
/// index into the pattern; `line` and `column` are 1-based.
pub(all) struct Position {
  offset : Int32
  line : Int32
  column : Int32
} derive(Debug, Eq, Compare)

///|
/// A span of a regular expression, from `start` (inclusive) to `end`
/// (exclusive).
pub(all) struct Span {
  start : Position
  end : Position
} derive(Debug, Eq, Compare)

///|
pub fn Span::new(start : Position, end : Position) -> Span {
  { start, end, }
}

///|
fn Span::splat(pos : Position) -> Span {
  { start: pos, end: pos, }
}

///|
fn Span::with_end(self : Span, end : Position) -> Span {
  { start: self.start, end, }
}

///|
pub fn Span::is_one_line(self : Span) -> Bool {
  self.start.line == self.end.line
}

///|
pub(all) enum LiteralKind {
  Verbatim
  Meta
  Superfluous
  Octal
  HexFixed(HexLiteralKind)
  HexBrace(HexLiteralKind)
  Special
} derive(Debug, Eq)

///|
pub(all) enum HexLiteralKind {
  X
  UnicodeShort
  UnicodeLong
} derive(Debug, Eq)

///|
fn HexLiteralKind::digits(self : HexLiteralKind) -> Int32 {
  match self {
    X => 2
    UnicodeShort => 4
    UnicodeLong => 8
  }
}

///|
pub(all) struct Literal {
  span : Span
  kind : LiteralKind
  c : Char
} derive(Debug, Eq)

///|
/// If this literal was written as a `\x` hex escape with a value <= 0xFF,
/// returns that byte.
pub fn Literal::byte(self : Literal) -> Int32? {
  match self.kind {
    HexFixed(X) | HexBrace(X) =>
      if self.c.to_int() <= 0xFF {
        Some(self.c.to_int())
      } else {
        None
      }
    _ => None
  }
}

///|
pub(all) enum AssertionKind {
  StartLine
  EndLine
  StartText
  EndText
  WordBoundary
  NotWordBoundary
  WordBoundaryStart
  WordBoundaryEnd
  WordBoundaryStartAngle
  WordBoundaryEndAngle
  WordBoundaryStartHalf
  WordBoundaryEndHalf
} derive(Debug, Eq)

///|
pub(all) enum ClassPerlKind {
  Digit
  Space
  Word
} derive(Debug, Eq)

///|
pub(all) enum ClassAsciiKind {
  Alnum
  Alpha
  Ascii
  Blank
  Cntrl
  Digit
  Graph
  Lower
  Print
  Punct
  Space
  Upper
  Word
  Xdigit
} derive(Debug, Eq)

///|
fn ClassAsciiKind::from_name(name : String) -> ClassAsciiKind? {
  match name {
    "alnum" => Some(Alnum)
    "alpha" => Some(Alpha)
    "ascii" => Some(Ascii)
    "blank" => Some(Blank)
    "cntrl" => Some(Cntrl)
    "digit" => Some(Digit)
    "graph" => Some(Graph)
    "lower" => Some(Lower)
    "print" => Some(Print)
    "punct" => Some(Punct)
    "space" => Some(Space)
    "upper" => Some(Upper)
    "word" => Some(Word)
    "xdigit" => Some(Xdigit)
    _ => None
  }
}

///|
pub(all) enum ClassUnicodeOpKind {
  Equal
  Colon
  NotEqual
} derive(Debug, Eq)

///|
pub(all) enum ClassUnicodeKind {
  OneLetter(Char)
  Named(String)
  NamedValue(ClassUnicodeOpKind, String, String)
} derive(Debug, Eq)

///|
pub(all) struct ClassUnicode {
  span : Span
  negated : Bool
  kind : ClassUnicodeKind
} derive(Debug, Eq)

///|
pub fn ClassUnicode::is_negated(self : ClassUnicode) -> Bool {
  match self.kind {
    NamedValue(NotEqual, _, _) => !self.negated
    _ => self.negated
  }
}

///|
pub(all) enum ClassSetBinaryOpKind {
  Intersection
  Difference
  SymmetricDifference
} derive(Debug, Eq)

///|
pub(all) enum ClassSetItem {
  Empty(Span)
  Literal(Literal)
  Range(Span, Literal, Literal)
  Ascii(Span, ClassAsciiKind, Bool)
  Unicode(ClassUnicode)
  Perl(Span, ClassPerlKind, Bool)
  Bracketed(ClassBracketed)
  Union(Span, Array[ClassSetItem])
} derive(Debug, Eq)

///|
pub(all) enum ClassSet {
  Item(ClassSetItem)
  BinaryOp(Span, ClassSetBinaryOpKind, ClassSet, ClassSet)
} derive(Debug, Eq)

///|
pub(all) struct ClassBracketed {
  mut span : Span
  negated : Bool
  mut kind : ClassSet
} derive(Debug, Eq)

///|
pub(all) enum Flag {
  CaseInsensitive
  MultiLine
  DotMatchesNewLine
  SwapGreed
  Unicode
  CRLF
  IgnoreWhitespace
} derive(Debug, Eq)

///|
pub(all) enum FlagsItemKind {
  Negation
  Flag(Flag)
} derive(Debug, Eq)

///|
pub(all) struct FlagsItem {
  span : Span
  kind : FlagsItemKind
} derive(Debug, Eq)

///|
pub(all) struct Flags {
  mut span : Span
  items : Array[FlagsItem]
} derive(Debug, Eq)

///|
/// Adds an item; returns the index of a duplicate if there was one.
fn Flags::add_item(self : Flags, item : FlagsItem) -> Int32? {
  for i, x in self.items {
    if x.kind == item.kind {
      return Some(i)
    }
  }
  self.items.push(item)
  None
}

///|
/// Returns the state of the given flag: `Some(true)` if enabled,
/// `Some(false)` if negated and `None` if absent.
pub fn Flags::flag_state(self : Flags, flag : Flag) -> Bool? {
  let mut negated = false
  for x in self.items {
    match x.kind {
      Negation => negated = true
      Flag(f) => if f == flag { return Some(!negated) }
    }
  }
  None
}

///|
pub(all) enum RepetitionRange {
  Exactly(Int32)
  AtLeast(Int32)
  Bounded(Int32, Int32)
} derive(Debug, Eq)

///|
pub(all) enum RepetitionKind {
  ZeroOrOne
  ZeroOrMore
  OneOrMore
  Range(RepetitionRange)
} derive(Debug, Eq)

///|
pub(all) struct Repetition {
  span : Span
  kind : RepetitionKind
  greedy : Bool
  ast : Ast
} derive(Debug, Eq)

///|
pub(all) enum GroupKind {
  CaptureIndex(Int32)
  CaptureName(Int32, String)
  NonCapturing(Flags)
} derive(Debug, Eq)

///|
pub(all) struct Group {
  mut span : Span
  kind : GroupKind
  mut ast : Ast
} derive(Debug, Eq)

///|
/// An abstract syntax tree for a single regular expression.
pub(all) enum Ast {
  Empty(Span)
  SetFlags(Span, Flags)
  Literal(Literal)
  Dot(Span)
  Assertion(Span, AssertionKind)
  ClassUnicode(ClassUnicode)
  ClassPerl(Span, ClassPerlKind, Bool)
  ClassBracketed(ClassBracketed)
  Repetition(Repetition)
  Group(Group)
  Alternation(Span, Array[Ast])
  Concat(Span, Array[Ast])
} derive(Debug, Eq)

///|
pub fn Ast::span(self : Ast) -> Span {
  match self {
    Empty(s) | SetFlags(s, _) | Dot(s) | Assertion(s, _) => s
    Literal(x) => x.span
    ClassUnicode(x) => x.span
    ClassPerl(s, _, _) => s
    ClassBracketed(x) => x.span
    Repetition(x) => x.span
    Group(x) => x.span
    Alternation(s, _) | Concat(s, _) => s
  }
}

///|
fn ClassSetItem::span(self : ClassSetItem) -> Span {
  match self {
    Empty(s) | Range(s, _, _) | Ascii(s, _, _) | Perl(s, _, _) | Union(s, _) =>
      s
    Literal(x) => x.span
    Unicode(x) => x.span
    Bracketed(x) => x.span
  }
}

///|
fn ClassSet::span(self : ClassSet) -> Span {
  match self {
    Item(x) => x.span()
    BinaryOp(s, _, _, _) => s
  }
}

///|
/// Returns true if the given character has significance in a regex.
pub fn is_meta_character(c : Char) -> Bool {
  match c {
    '\\'
    | '.'
    | '+'
    | '*'
    | '?'
    | '('
    | ')'
    | '|'
    | '['
    | ']'
    | '{'
    | '}'
    | '^'
    | '$'
    | '#'
    | '&'
    | '-'
    | '~' => true
    _ => false
  }
}

///|
/// Returns true if the given character can be escaped in a regex.
pub fn is_escapeable_character(c : Char) -> Bool {
  if is_meta_character(c) {
    return true
  }
  if c.to_int() > 0x7F {
    return false
  }
  match c {
    '0'..<='9' | 'A'..<='Z' | 'a'..<='z' => false
    '<' | '>' => false
    _ => true
  }
}

///|
/// Escapes all regular expression meta characters in `text`.
pub fn escape(text : String) -> String {
  let buf = StringBuilder()
  for c in text {
    if is_meta_character(c) {
      buf.write_char('\\')
    }
    buf.write_char(c)
  }
  buf.to_string()
}
