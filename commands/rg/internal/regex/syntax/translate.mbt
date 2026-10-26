///|
priv struct TFlags {
  case_insensitive : Bool?
  multi_line : Bool?
  dot_matches_new_line : Bool?
  swap_greed : Bool?
  unicode : Bool?
  crlf : Bool?
}

///|
fn TFlags::from_ast(ast : Flags) -> TFlags {
  let mut ci = None
  let mut ml = None
  let mut dot = None
  let mut sg = None
  let mut uni = None
  let mut crlf = None
  let mut enable = true
  for item in ast.items {
    match item.kind {
      Negation => enable = false
      Flag(CaseInsensitive) => ci = Some(enable)
      Flag(MultiLine) => ml = Some(enable)
      Flag(DotMatchesNewLine) => dot = Some(enable)
      Flag(SwapGreed) => sg = Some(enable)
      Flag(Unicode) => uni = Some(enable)
      Flag(CRLF) => crlf = Some(enable)
      Flag(IgnoreWhitespace) => ()
    }
  }
  {
    case_insensitive: ci,
    multi_line: ml,
    dot_matches_new_line: dot,
    swap_greed: sg,
    unicode: uni,
    crlf,
  }
}

///|
fn TFlags::merge(self : TFlags, prev : TFlags) -> TFlags {
  fn m(a : Bool?, b : Bool?) -> Bool? {
    match a {
      None => b
      _ => a
    }
  }

  {
    case_insensitive: m(self.case_insensitive, prev.case_insensitive),
    multi_line: m(self.multi_line, prev.multi_line),
    dot_matches_new_line: m(
      self.dot_matches_new_line,
      prev.dot_matches_new_line,
    ),
    swap_greed: m(self.swap_greed, prev.swap_greed),
    unicode: m(self.unicode, prev.unicode),
    crlf: m(self.crlf, prev.crlf),
  }
}

///|
/// Configuration for translating an AST to an HIR.
pub(all) struct TranslatorConfig {
  utf8 : Bool
  line_terminator : Int32
  case_insensitive : Bool
  multi_line : Bool
  dot_matches_new_line : Bool
  crlf : Bool
  swap_greed : Bool
  unicode : Bool
}

///|
pub fn TranslatorConfig::default() -> TranslatorConfig {
  {
    utf8: true,
    line_terminator: '\n',
    case_insensitive: false,
    multi_line: false,
    dot_matches_new_line: false,
    crlf: false,
    swap_greed: false,
    unicode: true,
  }
}

///|
priv struct Translator {
  pattern : String
  utf8 : Bool
  line_terminator : Int32
  mut flags : TFlags
}

///|
fn Translator::error(
  self : Translator,
  span : Span,
  kind : ErrorKind,
) -> SyntaxError {
  SyntaxError(kind~, pattern=self.pattern, span~)
}

///|
fn Translator::unicode(self : Translator) -> Bool {
  self.flags.unicode.unwrap_or(true)
}

///|
fn Translator::case_insensitive(self : Translator) -> Bool {
  self.flags.case_insensitive.unwrap_or(false)
}

///|
fn Translator::set_flags(self : Translator, ast : Flags) -> TFlags {
  let old = self.flags
  self.flags = TFlags::from_ast(ast).merge(old)
  old
}

///|
/// Translates an AST into an HIR.
pub fn translate(
  pattern : String,
  ast : Ast,
  config~ : TranslatorConfig = TranslatorConfig::default(),
) -> Hir raise SyntaxError {
  let t : Translator = {
    pattern,
    utf8: config.utf8,
    line_terminator: config.line_terminator,
    flags: {
      case_insensitive: if config.case_insensitive {
        Some(true)
      } else {
        None
      },
      multi_line: if config.multi_line {
        Some(true)
      } else {
        None
      },
      dot_matches_new_line: if config.dot_matches_new_line {
        Some(true)
      } else {
        None
      },
      crlf: if config.crlf {
        Some(true)
      } else {
        None
      },
      swap_greed: if config.swap_greed {
        Some(true)
      } else {
        None
      },
      unicode: if config.unicode {
        None
      } else {
        Some(false)
      },
    },
  }
  t.translate(ast)
}

///|
fn Translator::translate(self : Translator, ast : Ast) -> Hir raise SyntaxError {
  match ast {
    Empty(_) => Hir::empty()
    SetFlags(_, flags) => {
      ignore(self.set_flags(flags))
      Hir::empty()
    }
    Literal(lit) =>
      match self.literal_to_scalar(lit) {
        Right(byte) => Hir::literal(Bytes::make(1, byte.to_byte()))
        Left(c) =>
          match self.case_fold_char(c) {
            None => {
              let buf = Buffer()
              encode_utf8(buf, c)
              Hir::literal(buf.to_bytes())
            }
            Some(h) => h
          }
      }
    Dot(span) => self.hir_dot(span)
    Assertion(_, kind) => self.hir_assertion(kind)
    ClassPerl(span, kind, negated) =>
      if self.unicode() {
        Hir::class(self.perl_unicode_class(span, kind, negated))
      } else {
        Hir::class(self.perl_byte_class(span, kind, negated))
      }
    ClassUnicode(cls) => Hir::class(self.unicode_class(cls))
    ClassBracketed(b) => Hir::class(self.bracketed(b))
    Repetition(rep) => {
      let sub = self.translate(rep.ast)
      let (min, max) = match rep.kind {
        ZeroOrOne => (0, Some(1))
        ZeroOrMore => (0, None)
        OneOrMore => (1, None)
        Range(Exactly(m)) => (m, Some(m))
        Range(AtLeast(m)) => (m, None)
        Range(Bounded(m, n)) => (m, Some(n))
      }
      let greedy = if self.flags.swap_greed.unwrap_or(false) {
        !rep.greedy
      } else {
        rep.greedy
      }
      Hir::repetition(min, max, greedy, sub)
    }
    Group(g) => {
      let old = match g.kind {
        NonCapturing(flags) => self.set_flags(flags)
        _ => self.flags
      }
      let sub = self.translate(g.ast)
      self.flags = old
      match g.kind {
        CaptureIndex(i) => Hir::capture(i, None, sub)
        CaptureName(i, name) => Hir::capture(i, Some(name), sub)
        NonCapturing(_) => sub
      }
    }
    Concat(_, xs) => {
      let out = []
      for x in xs {
        let h = self.translate(x)
        if !(h.kind is Empty) {
          out.push(h)
        }
      }
      Hir::concat(out)
    }
    Alternation(_, xs) => {
      let out = []
      for x in xs {
        out.push(self.translate(x))
      }
      Hir::alternation(out)
    }
  }
}

///|
fn Translator::literal_to_scalar(
  self : Translator,
  lit : Literal,
) -> Either[Int32, Int32] raise SyntaxError {
  if self.unicode() {
    return Left(lit.c.to_int())
  }
  match lit.byte() {
    None => Left(lit.c.to_int())
    Some(byte) =>
      if byte <= 0x7F {
        Left(byte)
      } else if self.utf8 {
        raise self.error(lit.span, InvalidUtf8)
      } else {
        Right(byte)
      }
  }
}

///|
fn Translator::case_fold_char(self : Translator, c : Int32) -> Hir? {
  if !self.case_insensitive() {
    return None
  }
  if self.unicode() {
    if !@unicode.fold_overlaps(c, c) {
      return None
    }
    Some(Hir::class(Class::Unicode([(c, c)]).case_fold_simple()))
  } else {
    if !((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) {
      return None
    }
    Some(Hir::class(Class::Bytes([(c, c)]).case_fold_simple()))
  }
}

///|
fn Translator::hir_dot(self : Translator, span : Span) -> Hir raise SyntaxError {
  let lineterm = self.line_terminator
  let unicode = self.unicode()
  if self.utf8 && (!unicode || lineterm > 0x7F) {
    raise self.error(span, InvalidUtf8)
  }
  let crlf = self.flags.crlf.unwrap_or(false)
  let dot = if self.flags.dot_matches_new_line.unwrap_or(false) {
    if unicode {
      Dot::AnyChar
    } else {
      AnyByte
    }
  } else if unicode {
    if crlf {
      AnyCharExceptCRLF
    } else {
      if lineterm > 0x7F {
        raise self.error(span, InvalidLineTerminator)
      }
      AnyCharExcept(lineterm)
    }
  } else if crlf {
    AnyByteExceptCRLF
  } else {
    AnyByteExcept(lineterm)
  }
  Hir::dot(dot)
}

///|
fn Translator::hir_assertion(self : Translator, kind : AssertionKind) -> Hir {
  let unicode = self.unicode()
  let multi_line = self.flags.multi_line.unwrap_or(false)
  let crlf = self.flags.crlf.unwrap_or(false)
  let look = match kind {
    StartLine =>
      if multi_line {
        if crlf {
          Look::StartCRLF
        } else {
          StartLF
        }
      } else {
        Start
      }
    EndLine => if multi_line { if crlf { EndCRLF } else { EndLF } } else { End }
    StartText => Start
    EndText => End
    WordBoundary => if unicode { WordUnicode } else { WordAscii }
    NotWordBoundary => if unicode { WordUnicodeNegate } else { WordAsciiNegate }
    WordBoundaryStart | WordBoundaryStartAngle =>
      if unicode {
        WordStartUnicode
      } else {
        WordStartAscii
      }
    WordBoundaryEnd | WordBoundaryEndAngle =>
      if unicode {
        WordEndUnicode
      } else {
        WordEndAscii
      }
    WordBoundaryStartHalf =>
      if unicode {
        WordStartHalfUnicode
      } else {
        WordStartHalfAscii
      }
    WordBoundaryEndHalf =>
      if unicode {
        WordEndHalfUnicode
      } else {
        WordEndHalfAscii
      }
  }
  Hir::look(look)
}

///|
fn ascii_class_ranges(kind : ClassAsciiKind) -> Array[(Int32, Int32)] {
  match kind {
    Alnum => [('0', '9'), ('A', 'Z'), ('a', 'z')]
    Alpha => [('A', 'Z'), ('a', 'z')]
    Ascii => [(0, 0x7F)]
    Blank => [('\t', '\t'), (' ', ' ')]
    Cntrl => [(0, 0x1F), (0x7F, 0x7F)]
    Digit => [('0', '9')]
    Graph => [('!', '~')]
    Lower => [('a', 'z')]
    Print => [(' ', '~')]
    Punct => [('!', '/'), (':', '@'), ('[', '`'), ('{', '~')]
    Space =>
      [
        ('\t', '\t'),
        ('\n', '\n'),
        (0x0B, 0x0B),
        (0x0C, 0x0C),
        ('\r', '\r'),
        (' ', ' '),
      ]
    Upper => [('A', 'Z')]
    Word => [('0', '9'), ('A', 'Z'), ('_', '_'), ('a', 'z')]
    Xdigit => [('0', '9'), ('A', 'F'), ('a', 'f')]
  }
}

///|
fn Translator::perl_unicode_class(
  self : Translator,
  _span : Span,
  kind : ClassPerlKind,
  negated : Bool,
) -> Class {
  ignore(self)
  let ranges = match kind {
    Digit => @unicode.perl_digit()
    Space => @unicode.perl_space()
    Word => @unicode.perl_word()
  }
  let cls = Class::new_unicode(ranges)
  if negated {
    cls.negate()
  } else {
    cls
  }
}

///|
fn Translator::perl_byte_class(
  self : Translator,
  span : Span,
  kind : ClassPerlKind,
  negated : Bool,
) -> Class raise SyntaxError {
  let ak = match kind {
    Digit => ClassAsciiKind::Digit
    Space => Space
    Word => Word
  }
  let mut cls = Class::new_bytes(ascii_class_ranges(ak))
  if negated {
    cls = cls.negate()
  }
  if self.utf8 && !cls.is_ascii() {
    raise self.error(span, InvalidUtf8)
  }
  cls
}

///|
fn Translator::unicode_class(
  self : Translator,
  cls : ClassUnicode,
) -> Class raise SyntaxError {
  if !self.unicode() {
    raise self.error(cls.span, UnicodeNotAllowed)
  }
  let query = match cls.kind {
    OneLetter(c) => @unicode.ClassQuery::OneLetter(c)
    Named(name) => Binary(name)
    NamedValue(_, name, value) => ByValue(name, value)
  }
  let ranges = @unicode.class(query) catch {
    PropertyNotFound => raise self.error(cls.span, UnicodePropertyNotFound)
    PropertyValueNotFound =>
      raise self.error(cls.span, UnicodePropertyValueNotFound)
  }
  self.unicode_fold_and_negate(cls.is_negated(), Class::new_unicode(ranges))
}

///|
fn Translator::unicode_fold_and_negate(
  self : Translator,
  negated : Bool,
  cls : Class,
) -> Class {
  let mut cls = cls
  if self.case_insensitive() {
    cls = cls.case_fold_simple()
  }
  if negated {
    cls = cls.negate()
  }
  cls
}

///|
fn Translator::bytes_fold_and_negate(
  self : Translator,
  span : Span,
  negated : Bool,
  cls : Class,
) -> Class raise SyntaxError {
  let mut cls = cls
  if self.case_insensitive() {
    cls = cls.case_fold_simple()
  }
  if negated {
    cls = cls.negate()
  }
  if self.utf8 && !cls.is_ascii() {
    raise self.error(span, InvalidUtf8)
  }
  cls
}

///|
fn Translator::class_literal_byte(
  self : Translator,
  lit : Literal,
) -> Int32 raise SyntaxError {
  match self.literal_to_scalar(lit) {
    Right(b) => b
    Left(c) =>
      if c <= 0x7F {
        c
      } else {
        raise self.error(lit.span, UnicodeNotAllowed)
      }
  }
}

///|
fn Translator::empty_class(self : Translator) -> Class {
  if self.unicode() {
    Class::Unicode([])
  } else {
    Bytes([])
  }
}

///|
fn Translator::bracketed(
  self : Translator,
  b : ClassBracketed,
) -> Class raise SyntaxError {
  let cls = self.class_set(b.kind, self.empty_class())
  if self.unicode() {
    self.unicode_fold_and_negate(b.negated, cls)
  } else {
    self.bytes_fold_and_negate(b.span, b.negated, cls)
  }
}

///|
/// Adds the given class set to `acc`.
fn Translator::class_set(
  self : Translator,
  set : ClassSet,
  acc : Class,
) -> Class raise SyntaxError {
  match set {
    Item(item) => self.class_set_item(item, acc)
    BinaryOp(_, kind, lhs, rhs) => {
      let mut l = self.class_set(lhs, self.empty_class())
      let mut r = self.class_set(rhs, self.empty_class())
      if self.case_insensitive() {
        r = r.case_fold_simple()
        l = l.case_fold_simple()
      }
      let res = match kind {
        Intersection => l.intersect(r)
        Difference => l.difference(r)
        SymmetricDifference => l.symmetric_difference(r)
      }
      acc.union(res)
    }
  }
}

///|
fn Translator::class_set_item(
  self : Translator,
  item : ClassSetItem,
  acc : Class,
) -> Class raise SyntaxError {
  match item {
    Empty(_) => acc
    Literal(x) =>
      if self.unicode() {
        acc.union(Unicode([(x.c.to_int(), x.c.to_int())]))
      } else {
        let b = self.class_literal_byte(x)
        acc.union(Bytes([(b, b)]))
      }
    Range(_, s, e) =>
      if self.unicode() {
        acc.union(Class::new_unicode([(s.c.to_int(), e.c.to_int())]))
      } else {
        let s = self.class_literal_byte(s)
        let e = self.class_literal_byte(e)
        acc.union(Class::new_bytes([(s, e)]))
      }
    Ascii(span, kind, negated) =>
      if self.unicode() {
        acc.union(
          self.unicode_fold_and_negate(
            negated,
            Class::new_unicode(ascii_class_ranges(kind)),
          ),
        )
      } else {
        acc.union(
          self.bytes_fold_and_negate(
            span,
            negated,
            Class::new_bytes(ascii_class_ranges(kind)),
          ),
        )
      }
    Unicode(cls) => {
      let x = self.unicode_class(cls)
      acc.union(x)
    }
    Perl(span, kind, negated) =>
      if self.unicode() {
        acc.union(self.perl_unicode_class(span, kind, negated))
      } else {
        acc.union(self.perl_byte_class(span, kind, negated))
      }
    Bracketed(b) => {
      let inner = self.class_set(b.kind, self.empty_class())
      let inner = if self.unicode() {
        self.unicode_fold_and_negate(b.negated, inner)
      } else {
        self.bytes_fold_and_negate(b.span, b.negated, inner)
      }
      acc.union(inner)
    }
    Union(_, items) => {
      let mut acc = acc
      for x in items {
        acc = self.class_set_item(x, acc)
      }
      acc
    }
  }
}
