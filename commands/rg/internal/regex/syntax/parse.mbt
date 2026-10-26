///|
priv enum Primitive {
  PLiteral(Literal)
  PAssertion(Span, AssertionKind)
  PDot(Span)
  PPerl(Span, ClassPerlKind, Bool)
  PUnicode(ClassUnicode)
}

///|
fn Primitive::span(self : Primitive) -> Span {
  match self {
    PLiteral(x) => x.span
    PAssertion(s, _) | PDot(s) | PPerl(s, _, _) => s
    PUnicode(x) => x.span
  }
}

///|
fn Primitive::into_ast(self : Primitive) -> Ast {
  match self {
    PLiteral(x) => Literal(x)
    PAssertion(s, k) => Assertion(s, k)
    PDot(s) => Dot(s)
    PPerl(s, k, n) => ClassPerl(s, k, n)
    PUnicode(x) => ClassUnicode(x)
  }
}

///|
priv struct ConcatB {
  mut span : Span
  asts : Array[Ast]
}

///|
fn ConcatB::into_ast(self : ConcatB) -> Ast {
  match self.asts.length() {
    0 => Empty(self.span)
    1 => self.asts[0]
    _ => Concat(self.span, self.asts)
  }
}

///|
priv struct AltB {
  mut span : Span
  asts : Array[Ast]
}

///|
fn AltB::into_ast(self : AltB) -> Ast {
  match self.asts.length() {
    0 => Empty(self.span)
    1 => self.asts[0]
    _ => Alternation(self.span, self.asts)
  }
}

///|
priv struct UnionB {
  mut span : Span
  items : Array[ClassSetItem]
}

///|
fn UnionB::push(self : UnionB, item : ClassSetItem) -> Unit {
  if self.items.is_empty() {
    self.span = { start: item.span().start, end: self.span.end, }
  }
  self.span = { start: self.span.start, end: item.span().end, }
  self.items.push(item)
}

///|
fn UnionB::into_item(self : UnionB) -> ClassSetItem {
  match self.items.length() {
    0 => Empty(self.span)
    1 => self.items[0]
    _ => Union(self.span, self.items)
  }
}

///|
priv enum GroupState {
  GSGroup(ConcatB, Group, Bool)
  GSAlternation(AltB)
}

///|
priv enum ClassState {
  CSOpen(UnionB, ClassBracketed)
  CSOp(ClassSetBinaryOpKind, ClassSet)
}

///|
priv enum Either[L, R] {
  Left(L)
  Right(R)
}

///|
/// Configuration for the regex parser.
pub(all) struct ParserConfig {
  ignore_whitespace : Bool
  nest_limit : Int32
  octal : Bool
  empty_min_range : Bool
}

///|
pub fn ParserConfig::default() -> ParserConfig {
  {
    ignore_whitespace: false,
    nest_limit: 250,
    octal: false,
    empty_min_range: false,
  }
}

///|
priv struct Parser {
  pattern : String
  chars : Array[Char]
  mut pos : Position
  mut capture_index : Int32
  nest_limit : Int32
  octal : Bool
  empty_min_range : Bool
  mut ignore_whitespace : Bool
  stack_group : Array[GroupState]
  stack_class : Array[ClassState]
  capture_names : Array[(String, Span)]
}

///|
/// Parses the given pattern into an abstract syntax tree.
pub fn parse_ast(
  pattern : String,
  config~ : ParserConfig = ParserConfig::default(),
) -> Ast raise SyntaxError {
  let p : Parser = {
    pattern,
    chars: pattern.iter().collect(),
    pos: { offset: 0, line: 1, column: 1, },
    capture_index: 0,
    nest_limit: config.nest_limit,
    octal: config.octal,
    empty_min_range: config.empty_min_range,
    ignore_whitespace: config.ignore_whitespace,
    stack_group: [],
    stack_class: [],
    capture_names: [],
  }
  p.parse()
}

///|
fn Parser::error(self : Parser, span : Span, kind : ErrorKind) -> SyntaxError {
  SyntaxError(kind~, pattern=self.pattern, span~)
}

///|
fn Parser::offset(self : Parser) -> Int32 {
  self.pos.offset
}

///|
fn Parser::char(self : Parser) -> Char {
  self.chars[self.pos.offset]
}

///|
fn Parser::is_eof(self : Parser) -> Bool {
  self.pos.offset == self.chars.length()
}

///|
fn Parser::span(self : Parser) -> Span {
  Span::splat(self.pos)
}

///|
fn Parser::span_char(self : Parser) -> Span {
  let c = self.char()
  let next = if c == '\n' {
    { offset: self.pos.offset + 1, line: self.pos.line + 1, column: 1, }
  } else {
    {
      offset: self.pos.offset + 1,
      line: self.pos.line,
      column: self.pos.column + 1,
    }
  }
  Span::new(self.pos, next)
}

///|
fn Parser::bump(self : Parser) -> Bool {
  if self.is_eof() {
    return false
  }
  let { offset, line, column, } = self.pos
  if self.char() == '\n' {
    self.pos = { offset: offset + 1, line: line + 1, column: 1, }
  } else {
    self.pos = { offset: offset + 1, line, column: column + 1, }
  }
  !self.is_eof()
}

///|
fn Parser::bump_if(self : Parser, prefix : String) -> Bool {
  let pchars : Array[Char] = prefix.iter().collect()
  let off = self.offset()
  if off + pchars.length() > self.chars.length() {
    return false
  }
  for i, c in pchars {
    if self.chars[off + i] != c {
      return false
    }
  }
  for _ in 0..<pchars.length() {
    ignore(self.bump())
  }
  true
}

///|
fn Parser::is_lookaround_prefix(self : Parser) -> Bool {
  self.bump_if("?=") ||
  self.bump_if("?!") ||
  self.bump_if("?<=") ||
  self.bump_if("?<!")
}

///|
fn Parser::bump_and_bump_space(self : Parser) -> Bool {
  if !self.bump() {
    return false
  }
  self.bump_space()
  !self.is_eof()
}

///|
fn Parser::bump_space(self : Parser) -> Unit {
  if !self.ignore_whitespace {
    return
  }
  while !self.is_eof() {
    if is_whitespace_char(self.char()) {
      ignore(self.bump())
    } else if self.char() == '#' {
      ignore(self.bump())
      while !self.is_eof() {
        let c = self.char()
        ignore(self.bump())
        if c == '\n' {
          break
        }
      }
    } else {
      break
    }
  }
}

///|
fn Parser::peek(self : Parser) -> Char? {
  if self.is_eof() {
    return None
  }
  self.chars.get(self.offset() + 1)
}

///|
fn Parser::peek_space(self : Parser) -> Char? {
  if !self.ignore_whitespace {
    return self.peek()
  }
  if self.is_eof() {
    return None
  }
  let mut i = self.offset() + 1
  let mut in_comment = false
  while i < self.chars.length() {
    let c = self.chars[i]
    if is_whitespace_char(c) {
      i += 1
      continue
    } else if !in_comment && c == '#' {
      in_comment = true
    } else if in_comment && c == '\n' {
      in_comment = false
    } else {
      break
    }
    i += 1
  }
  self.chars.get(i)
}

///|
fn Parser::next_capture_index(self : Parser) -> Int32 {
  self.capture_index += 1
  self.capture_index
}

///|
fn Parser::add_capture_name(
  self : Parser,
  name : String,
  span : Span,
) -> Unit raise SyntaxError {
  for x in self.capture_names {
    if x.0 == name {
      raise self.error(span, GroupNameDuplicate(x.1))
    }
  }
  self.capture_names.push((name, span))
}

///|
fn Parser::push_alternate(self : Parser, concat : ConcatB) -> ConcatB {
  concat.span = concat.span.with_end(self.pos)
  self.push_or_add_alternation(concat)
  ignore(self.bump())
  { span: self.span(), asts: [], }
}

///|
fn Parser::push_or_add_alternation(self : Parser, concat : ConcatB) -> Unit {
  if self.stack_group.last() is Some(GSAlternation(alts)) {
    alts.asts.push(concat.into_ast())
    return
  }
  self.stack_group.push(
    GSAlternation({
      span: Span::new(concat.span.start, self.pos),
      asts: [concat.into_ast()],
    }),
  )
}

///|
fn Parser::push_group(
  self : Parser,
  concat : ConcatB,
) -> ConcatB raise SyntaxError {
  match self.parse_group() {
    Left((span, flags)) => {
      if flags.flag_state(IgnoreWhitespace) is Some(v) {
        self.ignore_whitespace = v
      }
      concat.asts.push(SetFlags(span, flags))
      concat
    }
    Right(group) => {
      let old = self.ignore_whitespace
      let new_ws = match group.kind {
        NonCapturing(flags) =>
          match flags.flag_state(IgnoreWhitespace) {
            Some(v) => v
            None => old
          }
        _ => old
      }
      self.stack_group.push(GSGroup(concat, group, old))
      self.ignore_whitespace = new_ws
      { span: self.span(), asts: [], }
    }
  }
}

///|
fn Parser::pop_group(
  self : Parser,
  group_concat : ConcatB,
) -> ConcatB raise SyntaxError {
  let (prior_concat, group, ignore_ws, alt) = match self.stack_group.pop() {
    Some(GSGroup(c, g, ws)) => (c, g, ws, None)
    Some(GSAlternation(alt)) =>
      match self.stack_group.pop() {
        Some(GSGroup(c, g, ws)) => (c, g, ws, Some(alt))
        _ => raise self.error(self.span_char(), GroupUnopened)
      }
    None => raise self.error(self.span_char(), GroupUnopened)
  }
  self.ignore_whitespace = ignore_ws
  group_concat.span = group_concat.span.with_end(self.pos)
  ignore(self.bump())
  group.span = group.span.with_end(self.pos)
  match alt {
    Some(alt) => {
      alt.span = alt.span.with_end(group_concat.span.end)
      alt.asts.push(group_concat.into_ast())
      group.ast = alt.into_ast()
    }
    None => group.ast = group_concat.into_ast()
  }
  prior_concat.asts.push(Group(group))
  prior_concat
}

///|
fn Parser::pop_group_end(
  self : Parser,
  concat : ConcatB,
) -> Ast raise SyntaxError {
  concat.span = concat.span.with_end(self.pos)
  let ast = match self.stack_group.pop() {
    None => concat.into_ast()
    Some(GSAlternation(alt)) => {
      alt.span = alt.span.with_end(self.pos)
      alt.asts.push(concat.into_ast())
      Alternation(alt.span, alt.asts)
    }
    Some(GSGroup(_, group, _)) => raise self.error(group.span, GroupUnclosed)
  }
  match self.stack_group.pop() {
    None => ast
    Some(GSAlternation(_)) => abort("unreachable")
    Some(GSGroup(_, group, _)) => raise self.error(group.span, GroupUnclosed)
  }
}

///|
fn Parser::push_class_open(
  self : Parser,
  parent_union : UnionB,
) -> UnionB raise SyntaxError {
  let (nested_set, nested_union) = self.parse_set_class_open()
  self.stack_class.push(CSOpen(parent_union, nested_set))
  nested_union
}

///|
fn Parser::pop_class(
  self : Parser,
  nested_union : UnionB,
) -> Either[UnionB, ClassBracketed] {
  let item = ClassSet::Item(nested_union.into_item())
  let prevset = self.pop_class_op(item)
  match self.stack_class.pop() {
    Some(CSOpen(union, set)) => {
      ignore(self.bump())
      set.span = set.span.with_end(self.pos)
      set.kind = prevset
      if self.stack_class.is_empty() {
        Right(set)
      } else {
        union.push(Bracketed(set))
        Left(union)
      }
    }
    _ => abort("unexpected class state")
  }
}

///|
fn Parser::unclosed_class_error(self : Parser) -> SyntaxError {
  for i = self.stack_class.length() - 1; i >= 0; i = i - 1 {
    if self.stack_class[i] is CSOpen(_, set) {
      return self.error(set.span, ClassUnclosed)
    }
  }
  abort("no open character class found")
}

///|
fn Parser::push_class_op(
  self : Parser,
  next_kind : ClassSetBinaryOpKind,
  next_union : UnionB,
) -> UnionB {
  let item = ClassSet::Item(next_union.into_item())
  let new_lhs = self.pop_class_op(item)
  self.stack_class.push(CSOp(next_kind, new_lhs))
  { span: self.span(), items: [], }
}

///|
fn Parser::pop_class_op(self : Parser, rhs : ClassSet) -> ClassSet {
  match self.stack_class.pop() {
    Some(CSOp(kind, lhs)) => {
      let span = Span::new(lhs.span().start, rhs.span().end)
      BinaryOp(span, kind, lhs, rhs)
    }
    Some(state) => {
      self.stack_class.push(state)
      rhs
    }
    None => abort("unreachable")
  }
}

///|
fn Parser::parse(self : Parser) -> Ast raise SyntaxError {
  let mut concat : ConcatB = { span: self.span(), asts: [], }
  while true {
    self.bump_space()
    if self.is_eof() {
      break
    }
    match self.char() {
      '(' => concat = self.push_group(concat)
      ')' => concat = self.pop_group(concat)
      '|' => concat = self.push_alternate(concat)
      '[' => {
        let class = self.parse_set_class()
        concat.asts.push(ClassBracketed(class))
      }
      '?' => concat = self.parse_uncounted_repetition(concat, ZeroOrOne)
      '*' => concat = self.parse_uncounted_repetition(concat, ZeroOrMore)
      '+' => concat = self.parse_uncounted_repetition(concat, OneOrMore)
      '{' => concat = self.parse_counted_repetition(concat)
      _ => concat.asts.push(self.parse_primitive().into_ast())
    }
  }
  let ast = self.pop_group_end(concat)
  check_nest_limit(self, ast)
  ast
}

///|
fn Parser::parse_uncounted_repetition(
  self : Parser,
  concat : ConcatB,
  kind : RepetitionKind,
) -> ConcatB raise SyntaxError {
  let op_start = self.pos
  let ast = match concat.asts.pop() {
    Some(ast) => ast
    None => raise self.error(self.span(), RepetitionMissing)
  }
  match ast {
    Empty(_) | SetFlags(_, _) =>
      raise self.error(self.span(), RepetitionMissing)
    _ => ()
  }
  ignore(op_start)
  let mut greedy = true
  if self.bump() && self.char() == '?' {
    greedy = false
    ignore(self.bump())
  }
  concat.asts.push(
    Repetition({ span: ast.span().with_end(self.pos), kind, greedy, ast, }),
  )
  concat
}

///|
fn Parser::parse_counted_repetition(
  self : Parser,
  concat : ConcatB,
) -> ConcatB raise SyntaxError {
  let start = self.pos
  let ast = match concat.asts.pop() {
    Some(ast) => ast
    None => raise self.error(self.span(), RepetitionMissing)
  }
  match ast {
    Empty(_) | SetFlags(_, _) =>
      raise self.error(self.span(), RepetitionMissing)
    _ => ()
  }
  if !self.bump_and_bump_space() {
    raise self.error(Span::new(start, self.pos), RepetitionCountUnclosed)
  }
  let count_start : Result[Int32, SyntaxError] = Ok(self.parse_decimal()) catch {
    e => Err(specialize_err(e, DecimalEmpty, RepetitionCountDecimalEmpty))
  }
  if self.is_eof() {
    raise self.error(Span::new(start, self.pos), RepetitionCountUnclosed)
  }
  let range = if self.char() == ',' {
    if !self.bump_and_bump_space() {
      raise self.error(Span::new(start, self.pos), RepetitionCountUnclosed)
    }
    if self.char() != '}' {
      let cs = match count_start {
        Ok(c) => c
        Err(err) =>
          if err.kind() == RepetitionCountDecimalEmpty {
            if self.empty_min_range {
              0
            } else {
              raise err
            }
          } else {
            raise err
          }
      }
      let count_end = self.parse_decimal() catch {
        e => raise specialize_err(e, DecimalEmpty, RepetitionCountDecimalEmpty)
      }
      RepetitionRange::Bounded(cs, count_end)
    } else {
      AtLeast(result_get(count_start))
    }
  } else {
    Exactly(result_get(count_start))
  }
  if self.is_eof() || self.char() != '}' {
    raise self.error(Span::new(start, self.pos), RepetitionCountUnclosed)
  }
  let mut greedy = true
  if self.bump_and_bump_space() && self.char() == '?' {
    greedy = false
    ignore(self.bump())
  }
  let op_span = Span::new(start, self.pos)
  if range is Bounded(s, e) && s > e {
    raise self.error(op_span, RepetitionCountInvalid)
  }
  concat.asts.push(
    Repetition({
      span: ast.span().with_end(self.pos),
      kind: Range(range),
      greedy,
      ast,
    }),
  )
  concat
}

///|
fn[T] result_get(r : Result[T, SyntaxError]) -> T raise SyntaxError {
  match r {
    Ok(x) => x
    Err(e) => raise e
  }
}

///|
fn specialize_err(
  e : SyntaxError,
  from : ErrorKind,
  to : ErrorKind,
) -> SyntaxError {
  let SyntaxError(kind~, pattern~, span~) = e
  if kind == from {
    SyntaxError(kind=to, pattern~, span~)
  } else {
    e
  }
}

///|
fn Parser::parse_group(
  self : Parser,
) -> Either[(Span, Flags), Group] raise SyntaxError {
  let open_span = self.span_char()
  ignore(self.bump())
  self.bump_space()
  if self.is_lookaround_prefix() {
    raise self.error(
      Span::new(open_span.start, self.span().end),
      UnsupportedLookAround,
    )
  }
  let inner_span = self.span()
  if self.bump_if("?P<") || self.bump_if("?<") {
    let capture_index = self.next_capture_index()
    let name = self.parse_capture_name()
    Right({
      span: open_span,
      kind: CaptureName(capture_index, name),
      ast: Empty(self.span()),
    })
  } else if self.bump_if("?") {
    if self.is_eof() {
      raise self.error(open_span, GroupUnclosed)
    }
    let flags = self.parse_flags()
    let char_end = self.char()
    ignore(self.bump())
    if char_end == ')' {
      if flags.items.is_empty() {
        raise self.error(inner_span, RepetitionMissing)
      }
      Left((Span::new(open_span.start, self.pos), flags))
    } else {
      Right({
        span: open_span,
        kind: NonCapturing(flags),
        ast: Empty(self.span()),
      })
    }
  } else {
    let capture_index = self.next_capture_index()
    Right({
      span: open_span,
      kind: CaptureIndex(capture_index),
      ast: Empty(self.span()),
    })
  }
}

///|
fn is_capture_char(c : Char, first : Bool) -> Bool {
  if first {
    c == '_' || is_alphabetic_char(c)
  } else {
    c == '_' || c == '.' || c == '[' || c == ']' || is_alphanumeric_char(c)
  }
}

///|
fn Parser::parse_capture_name(self : Parser) -> String raise SyntaxError {
  if self.is_eof() {
    raise self.error(self.span(), GroupNameUnexpectedEof)
  }
  let start = self.pos
  while true {
    if self.char() == '>' {
      break
    }
    if !is_capture_char(self.char(), self.pos == start) {
      raise self.error(self.span_char(), GroupNameInvalid)
    }
    if !self.bump() {
      break
    }
  }
  let end = self.pos
  if self.is_eof() {
    raise self.error(self.span(), GroupNameUnexpectedEof)
  }
  ignore(self.bump())
  let name = String::from_array(self.chars[start.offset:end.offset])
  if name.is_empty() {
    raise self.error(Span::new(start, start), GroupNameEmpty)
  }
  self.add_capture_name(name, Span::new(start, end))
  name
}

///|
fn Parser::parse_flags(self : Parser) -> Flags raise SyntaxError {
  let flags : Flags = { span: self.span(), items: [], }
  let mut last_was_negation : Span? = None
  while self.char() != ':' && self.char() != ')' {
    if self.char() == '-' {
      last_was_negation = Some(self.span_char())
      let item : FlagsItem = { span: self.span_char(), kind: Negation, }
      if flags.add_item(item) is Some(i) {
        raise self.error(
          self.span_char(),
          FlagRepeatedNegation(flags.items[i].span),
        )
      }
    } else {
      last_was_negation = None
      let item : FlagsItem = {
        span: self.span_char(),
        kind: Flag(self.parse_flag()),
      }
      if flags.add_item(item) is Some(i) {
        raise self.error(self.span_char(), FlagDuplicate(flags.items[i].span))
      }
    }
    if !self.bump() {
      raise self.error(self.span(), FlagUnexpectedEof)
    }
  }
  if last_was_negation is Some(span) {
    raise self.error(span, FlagDanglingNegation)
  }
  flags.span = flags.span.with_end(self.pos)
  flags
}

///|
fn Parser::parse_flag(self : Parser) -> Flag raise SyntaxError {
  match self.char() {
    'i' => CaseInsensitive
    'm' => MultiLine
    's' => DotMatchesNewLine
    'U' => SwapGreed
    'u' => Unicode
    'R' => CRLF
    'x' => IgnoreWhitespace
    _ => raise self.error(self.span_char(), FlagUnrecognized)
  }
}

///|
fn Parser::parse_primitive(self : Parser) -> Primitive raise SyntaxError {
  match self.char() {
    '\\' => self.parse_escape()
    '.' => {
      let ast = PDot(self.span_char())
      ignore(self.bump())
      ast
    }
    '^' => {
      let ast = PAssertion(self.span_char(), StartLine)
      ignore(self.bump())
      ast
    }
    '$' => {
      let ast = PAssertion(self.span_char(), EndLine)
      ignore(self.bump())
      ast
    }
    c => {
      let ast = PLiteral({ span: self.span_char(), kind: Verbatim, c, })
      ignore(self.bump())
      ast
    }
  }
}

///|
fn Parser::parse_escape(self : Parser) -> Primitive raise SyntaxError {
  let start = self.pos
  if !self.bump() {
    raise self.error(Span::new(start, self.pos), EscapeUnexpectedEof)
  }
  let c = self.char()
  match c {
    '0'..<='7' => {
      if !self.octal {
        raise self.error(
          Span::new(start, self.span_char().end),
          UnsupportedBackreference,
        )
      }
      let lit = self.parse_octal()
      return PLiteral({ ..lit, span: Span::new(start, lit.span.end), })
    }
    '8'..<='9' if !self.octal =>
      raise self.error(
        Span::new(start, self.span_char().end),
        UnsupportedBackreference,
      )
    'x' | 'u' | 'U' => {
      let lit = self.parse_hex()
      return PLiteral({ ..lit, span: Span::new(start, lit.span.end), })
    }
    'p' | 'P' => {
      let cls = self.parse_unicode_class()
      return PUnicode({ ..cls, span: Span::new(start, cls.span.end), })
    }
    'd' | 's' | 'w' | 'D' | 'S' | 'W' => {
      let (span, kind, negated) = self.parse_perl_class()
      return PPerl(Span::new(start, span.end), kind, negated)
    }
    _ => ()
  }
  ignore(self.bump())
  let span = Span::new(start, self.pos)
  if is_meta_character(c) {
    return PLiteral({ span, kind: Meta, c, })
  }
  if is_escapeable_character(c) {
    return PLiteral({ span, kind: Superfluous, c, })
  }
  let special = (c : Char) => PLiteral({ span, kind: Special, c, })
  match c {
    'a' => special('\u{07}')
    'f' => special('\u{0C}')
    't' => special('\t')
    'n' => special('\n')
    'r' => special('\r')
    'v' => special('\u{0B}')
    'A' => PAssertion(span, StartText)
    'z' => PAssertion(span, EndText)
    'b' => {
      let mut kind = AssertionKind::WordBoundary
      let mut span = span
      if !self.is_eof() && self.char() == '{' {
        if self.maybe_parse_special_word_boundary(start) is Some(k) {
          kind = k
          span = span.with_end(self.pos)
        }
      }
      PAssertion(span, kind)
    }
    'B' => PAssertion(span, NotWordBoundary)
    '<' => PAssertion(span, WordBoundaryStartAngle)
    '>' => PAssertion(span, WordBoundaryEndAngle)
    _ => raise self.error(span, EscapeUnrecognized)
  }
}

///|
fn Parser::maybe_parse_special_word_boundary(
  self : Parser,
  wb_start : Position,
) -> AssertionKind? raise SyntaxError {
  let is_valid_char = (c : Char) => {
    match c {
      'A'..<='Z' | 'a'..<='z' | '-' => true
      _ => false
    }
  }
  let start = self.pos
  if !self.bump_and_bump_space() {
    raise self.error(
      Span::new(wb_start, self.pos),
      SpecialWordOrRepetitionUnexpectedEof,
    )
  }
  let start_contents = self.pos
  if !is_valid_char(self.char()) {
    self.pos = start
    return None
  }
  let scratch = StringBuilder()
  while !self.is_eof() && is_valid_char(self.char()) {
    scratch.write_char(self.char())
    ignore(self.bump_and_bump_space())
  }
  if self.is_eof() || self.char() != '}' {
    raise self.error(Span::new(start, self.pos), SpecialWordBoundaryUnclosed)
  }
  let end = self.pos
  ignore(self.bump())
  match scratch.to_string() {
    "start" => Some(WordBoundaryStart)
    "end" => Some(WordBoundaryEnd)
    "start-half" => Some(WordBoundaryStartHalf)
    "end-half" => Some(WordBoundaryEndHalf)
    _ =>
      raise self.error(
        Span::new(start_contents, end),
        SpecialWordBoundaryUnrecognized,
      )
  }
}

///|
fn Parser::parse_octal(self : Parser) -> Literal {
  let start = self.pos
  while self.bump() &&
        self.char() >= '0' &&
        self.char() <= '7' &&
        self.pos.offset - start.offset <= 2 {

  }
  let end = self.pos
  let mut n = 0
  for i in start.offset..<end.offset {
    n = n * 8 + (self.chars[i].to_int() - '0'.to_int())
  }
  { span: Span::new(start, end), kind: Octal, c: n.unsafe_to_char(), }
}

///|
fn is_hex(c : Char) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
fn hex_value(c : Char) -> Int32 {
  let n = c.to_int()
  if c >= '0' && c <= '9' {
    n - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    n - 'a'.to_int() + 10
  } else {
    n - 'A'.to_int() + 10
  }
}

///|
/// Converts hex digits to a scalar value, if valid.
fn hex_to_char(digits : Array[Char]) -> Char? {
  if digits.length() > 8 {
    // Leading zeros are allowed; strip them.
    let mut i = 0
    while i < digits.length() && digits[i] == '0' {
      i += 1
    }
    if digits.length() - i > 8 {
      return None
    }
    return hex_to_char(digits[i:].to_owned())
  }
  let mut n : UInt64 = 0
  for d in digits {
    n = n * 16 + hex_value(d).to_uint64()
  }
  if n > 0x10FFFF || (n >= 0xD800 && n <= 0xDFFF) {
    None
  } else {
    Some(n.to_int().unsafe_to_char())
  }
}

///|
fn Parser::parse_hex(self : Parser) -> Literal raise SyntaxError {
  let hex_kind = match self.char() {
    'x' => HexLiteralKind::X
    'u' => UnicodeShort
    _ => UnicodeLong
  }
  if !self.bump_and_bump_space() {
    raise self.error(self.span(), EscapeUnexpectedEof)
  }
  if self.char() == '{' {
    self.parse_hex_brace(hex_kind)
  } else {
    self.parse_hex_digits(hex_kind)
  }
}

///|
fn Parser::parse_hex_digits(
  self : Parser,
  kind : HexLiteralKind,
) -> Literal raise SyntaxError {
  let scratch = []
  let start = self.pos
  for i in 0..<kind.digits() {
    if i > 0 && !self.bump_and_bump_space() {
      raise self.error(self.span(), EscapeUnexpectedEof)
    }
    if !is_hex(self.char()) {
      raise self.error(self.span_char(), EscapeHexInvalidDigit)
    }
    scratch.push(self.char())
  }
  ignore(self.bump_and_bump_space())
  let end = self.pos
  match hex_to_char(scratch) {
    None => raise self.error(Span::new(start, end), EscapeHexInvalid)
    Some(c) => { span: Span::new(start, end), kind: HexFixed(kind), c, }
  }
}

///|
fn Parser::parse_hex_brace(
  self : Parser,
  kind : HexLiteralKind,
) -> Literal raise SyntaxError {
  let scratch = []
  let brace_pos = self.pos
  let start = self.span_char().end
  while self.bump_and_bump_space() && self.char() != '}' {
    if !is_hex(self.char()) {
      raise self.error(self.span_char(), EscapeHexInvalidDigit)
    }
    scratch.push(self.char())
  }
  if self.is_eof() {
    raise self.error(Span::new(brace_pos, self.pos), EscapeUnexpectedEof)
  }
  let end = self.pos
  ignore(self.bump_and_bump_space())
  if scratch.is_empty() {
    raise self.error(Span::new(brace_pos, self.pos), EscapeHexEmpty)
  }
  match hex_to_char(scratch) {
    None => raise self.error(Span::new(start, end), EscapeHexInvalid)
    Some(c) => { span: Span::new(start, self.pos), kind: HexBrace(kind), c, }
  }
}

///|
fn Parser::parse_decimal(self : Parser) -> Int32 raise SyntaxError {
  // Decimals are parsed as u32 values (like Rust). Values that don't fit in
  // an Int are clamped, which is harmless since such repetitions can never
  // be compiled anyway.
  let mut n : Int64 = 0
  while !self.is_eof() && is_whitespace_char(self.char()) {
    ignore(self.bump())
  }
  let start = self.pos
  let mut overflow = false
  let mut count = 0
  while !self.is_eof() && self.char() >= '0' && self.char() <= '9' {
    let d = (self.char().to_int() - '0'.to_int()).to_int64()
    n = n * 10L + d
    if n > 0xFFFFFFFFL {
      overflow = true
      n = 0xFFFFFFFFL
    }
    count += 1
    ignore(self.bump_and_bump_space())
  }
  let span = Span::new(start, self.pos)
  while !self.is_eof() && is_whitespace_char(self.char()) {
    ignore(self.bump_and_bump_space())
  }
  if count == 0 {
    raise self.error(span, DecimalEmpty)
  }
  if overflow {
    raise self.error(span, DecimalInvalid)
  }
  if n > 0x7FFFFFFFL {
    0x7FFFFFFF
  } else {
    n.to_int()
  }
}

///|
fn Parser::parse_set_class(self : Parser) -> ClassBracketed raise SyntaxError {
  let mut union : UnionB = { span: self.span(), items: [], }
  while true {
    self.bump_space()
    if self.is_eof() {
      raise self.unclosed_class_error()
    }
    match self.char() {
      '[' => {
        if !self.stack_class.is_empty() {
          if self.maybe_parse_ascii_class() is Some(cls) {
            union.push(cls)
            continue
          }
        }
        union = self.push_class_open(union)
      }
      ']' =>
        match self.pop_class(union) {
          Left(nested) => union = nested
          Right(class) => return class
        }
      '&' if self.peek() == Some('&') => {
        ignore(self.bump_if("&&"))
        union = self.push_class_op(Intersection, union)
      }
      '-' if self.peek() == Some('-') => {
        ignore(self.bump_if("--"))
        union = self.push_class_op(Difference, union)
      }
      '~' if self.peek() == Some('~') => {
        ignore(self.bump_if("~~"))
        union = self.push_class_op(SymmetricDifference, union)
      }
      _ => union.push(self.parse_set_class_range())
    }
  }
  abort("unreachable")
}

///|
fn Parser::into_class_set_item(
  self : Parser,
  prim : Primitive,
) -> ClassSetItem raise SyntaxError {
  match prim {
    PLiteral(lit) => Literal(lit)
    PPerl(s, k, n) => Perl(s, k, n)
    PUnicode(cls) => Unicode(cls)
    x => raise self.error(x.span(), ClassEscapeInvalid)
  }
}

///|
fn Parser::into_class_literal(
  self : Parser,
  prim : Primitive,
) -> Literal raise SyntaxError {
  match prim {
    PLiteral(lit) => lit
    x => raise self.error(x.span(), ClassRangeLiteral)
  }
}

///|
fn Parser::parse_set_class_range(
  self : Parser,
) -> ClassSetItem raise SyntaxError {
  let prim1 = self.parse_set_class_item()
  self.bump_space()
  if self.is_eof() {
    raise self.unclosed_class_error()
  }
  if self.char() != '-' ||
    self.peek_space() == Some(']') ||
    self.peek_space() == Some('-') {
    return self.into_class_set_item(prim1)
  }
  if !self.bump_and_bump_space() {
    raise self.unclosed_class_error()
  }
  let prim2 = self.parse_set_class_item()
  let span = Span::new(prim1.span().start, prim2.span().end)
  let start = self.into_class_literal(prim1)
  let end = self.into_class_literal(prim2)
  if start.c > end.c {
    raise self.error(span, ClassRangeInvalid)
  }
  Range(span, start, end)
}

///|
fn Parser::parse_set_class_item(self : Parser) -> Primitive raise SyntaxError {
  if self.char() == '\\' {
    self.parse_escape()
  } else {
    let x = PLiteral({ span: self.span_char(), kind: Verbatim, c: self.char(), })
    ignore(self.bump())
    x
  }
}

///|
fn Parser::parse_set_class_open(
  self : Parser,
) -> (ClassBracketed, UnionB) raise SyntaxError {
  let start = self.pos
  if !self.bump_and_bump_space() {
    raise self.error(Span::new(start, self.pos), ClassUnclosed)
  }
  let negated = if self.char() != '^' {
    false
  } else {
    if !self.bump_and_bump_space() {
      raise self.error(Span::new(start, self.pos), ClassUnclosed)
    }
    true
  }
  let union : UnionB = { span: self.span(), items: [], }
  while self.char() == '-' {
    union.push(Literal({ span: self.span_char(), kind: Verbatim, c: '-', }))
    if !self.bump_and_bump_space() {
      raise self.error(Span::new(start, start), ClassUnclosed)
    }
  }
  if union.items.is_empty() && self.char() == ']' {
    union.push(Literal({ span: self.span_char(), kind: Verbatim, c: ']', }))
    if !self.bump_and_bump_space() {
      raise self.error(Span::new(start, self.pos), ClassUnclosed)
    }
  }
  let set : ClassBracketed = {
    span: Span::new(start, self.pos),
    negated,
    kind: Item(Empty(Span::new(union.span.start, union.span.start))),
  }
  (set, union)
}

///|
fn Parser::maybe_parse_ascii_class(self : Parser) -> ClassSetItem? {
  let start = self.pos
  let mut negated = false
  if !self.bump() || self.char() != ':' {
    self.pos = start
    return None
  }
  if !self.bump() {
    self.pos = start
    return None
  }
  if self.char() == '^' {
    negated = true
    if !self.bump() {
      self.pos = start
      return None
    }
  }
  let name_start = self.offset()
  while self.char() != ':' && self.bump() {

  }
  if self.is_eof() {
    self.pos = start
    return None
  }
  let name = String::from_array(self.chars[name_start:self.offset()])
  if !self.bump_if(":]") {
    self.pos = start
    return None
  }
  match ClassAsciiKind::from_name(name) {
    Some(kind) => Some(Ascii(Span::new(start, self.pos), kind, negated))
    None => {
      self.pos = start
      None
    }
  }
}

///|
fn Parser::parse_unicode_class(self : Parser) -> ClassUnicode raise SyntaxError {
  let negated = self.char() == 'P'
  if !self.bump_and_bump_space() {
    raise self.error(self.span(), EscapeUnexpectedEof)
  }
  if self.char() == '{' {
    let start = self.span_char().end
    let scratch = StringBuilder()
    while self.bump_and_bump_space() && self.char() != '}' {
      scratch.write_char(self.char())
    }
    if self.is_eof() {
      raise self.error(self.span(), EscapeUnexpectedEof)
    }
    ignore(self.bump())
    let name = scratch.to_string()
    let kind = if name.find("!=") is Some(i) {
      ClassUnicodeKind::NamedValue(
        NotEqual,
        name.view(end_offset=i).to_owned(),
        name.view(start_offset=i + 2).to_owned(),
      )
    } else if name.find(":") is Some(i) {
      NamedValue(
        Colon,
        name.view(end_offset=i).to_owned(),
        name.view(start_offset=i + 1).to_owned(),
      )
    } else if name.find("=") is Some(i) {
      NamedValue(
        Equal,
        name.view(end_offset=i).to_owned(),
        name.view(start_offset=i + 1).to_owned(),
      )
    } else {
      Named(name)
    }
    { span: Span::new(start, self.pos), negated, kind, }
  } else {
    let start = self.pos
    let c = self.char()
    if c == '\\' {
      raise self.error(self.span_char(), UnicodeClassInvalid)
    }
    ignore(self.bump_and_bump_space())
    { span: Span::new(start, self.pos), negated, kind: OneLetter(c), }
  }
}

///|
fn Parser::parse_perl_class(self : Parser) -> (Span, ClassPerlKind, Bool) {
  let c = self.char()
  let span = self.span_char()
  ignore(self.bump())
  let (negated, kind) = match c {
    'd' => (false, ClassPerlKind::Digit)
    'D' => (true, Digit)
    's' => (false, Space)
    'S' => (true, Space)
    'w' => (false, Word)
    _ => (true, Word)
  }
  (span, kind, negated)
}

///|
fn nest_incr(p : Parser, depth : Int32, span : Span) -> Int32 raise SyntaxError {
  let d = depth + 1
  if d > p.nest_limit {
    raise p.error(span, NestLimitExceeded(p.nest_limit))
  }
  d
}

///|
fn nest_visit_set(
  p : Parser,
  set : ClassSet,
  depth : Int32,
) -> Unit raise SyntaxError {
  match set {
    Item(item) => nest_visit_item(p, item, depth)
    BinaryOp(span, _, lhs, rhs) => {
      let d = nest_incr(p, depth, span)
      nest_visit_set(p, lhs, d)
      nest_visit_set(p, rhs, d)
    }
  }
}

///|
fn nest_visit_item(
  p : Parser,
  item : ClassSetItem,
  depth : Int32,
) -> Unit raise SyntaxError {
  match item {
    Bracketed(b) => nest_visit_set(p, b.kind, nest_incr(p, depth, b.span))
    Union(span, items) => {
      let d = nest_incr(p, depth, span)
      for x in items {
        nest_visit_item(p, x, d)
      }
    }
    _ => ()
  }
}

///|
fn nest_visit(p : Parser, ast : Ast, depth : Int32) -> Unit raise SyntaxError {
  match ast {
    ClassBracketed(b) => nest_visit_set(p, b.kind, nest_incr(p, depth, b.span))
    Repetition(r) => nest_visit(p, r.ast, nest_incr(p, depth, r.span))
    Group(g) => nest_visit(p, g.ast, nest_incr(p, depth, g.span))
    Alternation(span, xs) | Concat(span, xs) => {
      let d = nest_incr(p, depth, span)
      for x in xs {
        nest_visit(p, x, d)
      }
    }
    _ => ()
  }
}

///|
fn check_nest_limit(p : Parser, ast : Ast) -> Unit raise SyntaxError {
  nest_visit(p, ast, 0)
}
