///|
/// Describes a matching strategy for a particular pattern.
///
/// This provides a way to more quickly determine whether a pattern matches
/// a particular file path in a way that scales with a large number of
/// patterns. For example, if many patterns are of the form `*.ext`, then it's
/// possible to test whether any of those patterns matches by looking up a
/// file path's extension in a hash table.
priv enum MatchStrategy {
  /// A pattern matches if and only if the entire file path matches this
  /// literal string.
  Literal(String)
  /// A pattern matches if and only if the file path's basename matches this
  /// literal string.
  BasenameLiteral(String)
  /// A pattern matches if and only if the file path's extension matches this
  /// literal string.
  Extension(String)
  /// A pattern matches if and only if this prefix literal is a prefix of the
  /// candidate file path.
  Prefix(String)
  /// A pattern matches if and only if this suffix literal is a suffix of the
  /// candidate file path.
  ///
  /// An exception: if `component` is true, then `suffix` must appear at the
  /// beginning of a file path or immediately following a `/`.
  Suffix(suffix~ : String, component~ : Bool)
  /// A pattern matches only if the given extension matches the file path's
  /// extension. Note that this is a necessary but NOT sufficient criterion.
  /// Namely, if the extension matches, then a full regex search is still
  /// required.
  RequiredExtension(String)
  /// A regex needs to be used for matching.
  Regex
}

///|
/// Returns a matching strategy for the given pattern.
fn MatchStrategy::new(pat : Glob) -> MatchStrategy {
  if pat.basename_literal() is Some(lit) {
    BasenameLiteral(lit)
  } else if pat.literal() is Some(lit) {
    Literal(lit)
  } else if pat.ext() is Some(ext) {
    Extension(ext)
  } else if pat.prefix() is Some(prefix) {
    Prefix(prefix)
  } else if pat.suffix() is Some((suffix, component)) {
    Suffix(suffix~, component~)
  } else if pat.required_ext() is Some(ext) {
    RequiredExtension(ext)
  } else {
    Regex
  }
}

///|
priv struct GlobOptions {
  /// Whether to match case insensitively.
  case_insensitive : Bool
  /// Whether to require a literal separator to match a separator in a file
  /// path. e.g., when enabled, `*` won't match `/`.
  literal_separator : Bool
  /// Whether or not to use `\` to escape special characters.
  /// e.g., when enabled, `\*` will match a literal `*`.
  backslash_escape : Bool
  /// Whether or not an empty case in an alternate will be removed.
  /// e.g., when enabled, `{,a}` will match "" and "a".
  empty_alternates : Bool
  /// Whether or not an unclosed character class is allowed. When an unclosed
  /// character class is found, the opening `[` is treated as a literal `[`.
  /// When this isn't enabled, an opening `[` without a corresponding `]` is
  /// treated as an error.
  allow_unclosed_class : Bool
} derive(Eq, Hash, Debug)

///|
fn GlobOptions::default() -> GlobOptions {
  {
    case_insensitive: false,
    literal_separator: false,
    backslash_escape: !is_separator('\\'),
    empty_alternates: false,
    allow_unclosed_class: false,
  }
}

///|
priv enum Token {
  Literal(Char)
  Any
  ZeroOrMore
  RecursivePrefix
  RecursiveSuffix
  RecursiveZeroOrMore
  Class(negated~ : Bool, ranges~ : Array[(Char, Char)])
  Alternates(Array[Array[Token]])
} derive(Eq, Debug)

///|
/// Glob represents a successfully parsed shell glob pattern.
///
/// It cannot be used directly to match file paths, but it can be converted
/// to a regular expression string or a matcher.
pub struct Glob {
  priv glob : String
  priv re : String
  priv opts : GlobOptions
  priv tokens : Array[Token]
}

///|
pub impl Eq for Glob with fn equal(self, other) {
  self.glob == other.glob && self.opts == other.opts
}

///|
pub impl Hash for Glob with fn hash_combine(self, hasher) {
  hasher.combine(self.glob)
  hasher.combine(self.opts)
}

///|
pub impl Show for Glob with fn output(self, logger) {
  logger.write_string(self.glob)
}

///|
pub impl Debug for Glob with fn to_repr(self) {
  @debug.Repr::ctor("Glob", [(None, @debug.Repr::string(self.glob))])
}

///|
/// A matcher for a single pattern.
pub struct GlobMatcher {
  /// The underlying pattern.
  priv pat : Glob
  /// The pattern, as a compiled regex.
  priv re : @regex.Regex
}

///|
/// Tests whether the given path matches this pattern or not.
pub fn GlobMatcher::is_match(self : GlobMatcher, path : String) -> Bool {
  self.is_match_candidate(Candidate::new(path))
}

///|
/// Tests whether the given path matches this pattern or not.
pub fn GlobMatcher::is_match_candidate(
  self : GlobMatcher,
  path : Candidate,
) -> Bool {
  regex_is_match(self.re, path.path_arr)
}

///|
/// Returns the `Glob` used to compile this matcher.
pub fn GlobMatcher::glob(self : GlobMatcher) -> Glob {
  self.pat
}

///|
pub impl Debug for GlobMatcher with fn to_repr(self) {
  @debug.Repr::ctor("GlobMatcher", [(None, Debug::to_repr(self.pat))])
}

///|
/// A builder for a pattern.
///
/// This builder enables configuring the match semantics of a pattern. For
/// example, one can make matching case insensitive.
pub struct GlobBuilder {
  /// The glob pattern to compile.
  priv glob : String
  /// Options for the pattern.
  priv mut opts : GlobOptions
} derive(Debug)

///|
/// Builds a new pattern with default options.
pub fn Glob::new(glob : String) -> Glob raise GlobError {
  GlobBuilder::new(glob).build()
}

///|
/// Returns a matcher for this pattern.
pub fn Glob::compile_matcher(self : Glob) -> GlobMatcher {
  let re = new_regex(self.re) catch {
    e => abort("regex compilation shouldn't fail: \{e}")
  }
  { pat: self, re, }
}

///|
/// Returns the original glob pattern used to build this pattern.
pub fn Glob::glob(self : Glob) -> String {
  self.glob
}

///|
/// Returns the regular expression string for this glob.
///
/// Note that regular expressions for globs are intended to be matched on
/// arbitrary bytes instead of Unicode strings. In particular, globs are
/// frequently used on file paths, where there is no general guarantee that
/// file paths are themselves valid UTF-8.
pub fn Glob::regex(self : Glob) -> String {
  self.re
}

///|
/// Returns the pattern as a literal if and only if the pattern must match
/// an entire path exactly.
///
/// The basic format of these patterns is `{literal}`.
fn Glob::literal(self : Glob) -> String? {
  if self.opts.case_insensitive {
    return None
  }
  let lit = StringBuilder()
  for t in self.tokens {
    guard t is Literal(c) else { return None }
    lit.write_char(c)
  }
  let lit = lit.to_string()
  if lit.is_empty() {
    None
  } else {
    Some(lit)
  }
}

///|
/// Returns an extension if this pattern matches a file path if and only
/// if the file path has the extension returned.
///
/// Note that this extension returned differs from the extension that
/// std::path::Path::extension returns. Namely, this extension includes
/// the '.'. Also, paths like `.rs` are considered to have an extension
/// of `.rs`.
fn Glob::ext(self : Glob) -> String? {
  if self.opts.case_insensitive {
    return None
  }
  let start = match self.tokens.get(0) {
    None => return None
    Some(RecursivePrefix) => 1
    Some(_) => 0
  }
  match self.tokens.get(start) {
    Some(ZeroOrMore) =>
      // If there was no recursive prefix, then we only permit
      // `*` if `*` can match a `/`. For example, if `*` can't
      // match `/`, then `*.c` doesn't match `foo/bar.c`.
      if start == 0 && self.opts.literal_separator {
        return None
      }
    _ => return None
  }
  match self.tokens.get(start + 1) {
    Some(Literal('.')) => ()
    _ => return None
  }
  let lit = StringBuilder()
  lit.write_char('.')
  for t in self.tokens[start + 2:] {
    match t {
      Literal('.') | Literal('/') => return None
      Literal(c) => lit.write_char(c)
      _ => return None
    }
  }
  Some(lit.to_string())
}

///|
/// This is like `ext`, but returns an extension even if it isn't sufficient
/// to imply a match. Namely, if an extension is returned, then it is
/// necessary but not sufficient for a match.
fn Glob::required_ext(self : Glob) -> String? {
  if self.opts.case_insensitive {
    return None
  }
  // We don't care at all about the beginning of this pattern. All we
  // need to check for is if it ends with a literal of the form `.ext`.
  let ext : Array[Char] = [] // built in reverse
  for i = self.tokens.length() - 1; i >= 0; i = i - 1 {
    match self.tokens[i] {
      Literal('/') => return None
      Literal(c) => {
        ext.push(c)
        if c == '.' {
          break
        }
      }
      _ => return None
    }
  }
  if ext.last() != Some('.') {
    None
  } else {
    ext.rev_in_place()
    Some(String::from_array(ext))
  }
}

///|
/// Returns a literal prefix of this pattern if the entire pattern matches
/// if the literal prefix matches.
fn Glob::prefix(self : Glob) -> String? {
  if self.opts.case_insensitive {
    return None
  }
  let (end, need_sep) = match self.tokens.last() {
    None => return None
    Some(ZeroOrMore) => {
      if self.opts.literal_separator {
        // If a trailing `*` can't match a `/`, then we can't
        // assume a match of the prefix corresponds to a match
        // of the overall pattern. e.g., `foo/*` with
        // `literal_separator` enabled matches `foo/bar` but not
        // `foo/bar/baz`, even though `foo/bar/baz` has a `foo/`
        // literal prefix.
        return None
      }
      (self.tokens.length() - 1, false)
    }
    Some(RecursiveSuffix) => (self.tokens.length() - 1, true)
    Some(_) => (self.tokens.length(), false)
  }
  let lit = StringBuilder()
  for t in self.tokens[0:end] {
    guard t is Literal(c) else { return None }
    lit.write_char(c)
  }
  if need_sep {
    lit.write_char('/')
  }
  let lit = lit.to_string()
  if lit.is_empty() {
    None
  } else {
    Some(lit)
  }
}

///|
/// Returns a literal suffix of this pattern if the entire pattern matches
/// if the literal suffix matches.
///
/// If a literal suffix is returned and it must match either the entire
/// file path or be preceded by a `/`, then also return true. This happens
/// with a pattern like `**/foo/bar`. Namely, this pattern matches
/// `foo/bar` and `baz/foo/bar`, but not `foofoo/bar`. In this case, the
/// suffix returned is `/foo/bar` (but should match the entire path
/// `foo/bar`).
///
/// When this returns true, the suffix literal is guaranteed to start with
/// a `/`.
fn Glob::suffix(self : Glob) -> (String, Bool)? {
  if self.opts.case_insensitive {
    return None
  }
  let lit = StringBuilder()
  let (start, entire) = match self.tokens.get(0) {
    None => return None
    Some(RecursivePrefix) =>
      // We only care if this follows a path component if the next
      // token is a literal.
      if self.tokens.get(1) is Some(Literal(_)) {
        lit.write_char('/')
        (1, true)
      } else {
        (1, false)
      }
    Some(_) => (0, false)
  }
  let start = match self.tokens.get(start) {
    None => return None
    Some(ZeroOrMore) => {
      // If literal_separator is enabled, then a `*` can't
      // necessarily match everything, so reporting a suffix match
      // as a match of the pattern would be a false positive.
      if self.opts.literal_separator {
        return None
      }
      start + 1
    }
    Some(_) => start
  }
  for t in self.tokens[start:] {
    guard t is Literal(c) else { return None }
    lit.write_char(c)
  }
  let lit = lit.to_string()
  if lit.is_empty() || lit == "/" {
    None
  } else {
    Some((lit, entire))
  }
}

///|
/// If this pattern only needs to inspect the basename of a file path,
/// then the tokens corresponding to only the basename match are returned.
///
/// For example, given a pattern of `**/*.foo`, only the tokens
/// corresponding to `*.foo` are returned.
///
/// Note that this will return None if any match of the basename tokens
/// doesn't correspond to a match of the entire pattern. For example, the
/// glob `foo` only matches when a file path has a basename of `foo`, but
/// doesn't *always* match when a file path has a basename of `foo`. e.g.,
/// `foo` doesn't match `abc/foo`.
fn Glob::basename_tokens(self : Glob) -> ArrayView[Token]? {
  if self.opts.case_insensitive {
    return None
  }
  let start = match self.tokens.get(0) {
    Some(RecursivePrefix) => 1
    // With nothing to gobble up the parent portion of a path,
    // we can't assume that matching on only the basename is
    // correct.
    _ => return None
  }
  if self.tokens[start:].is_empty() {
    return None
  }
  for t in self.tokens[start:] {
    match t {
      Literal('/') => return None
      Literal(_) => () // OK
      Any | ZeroOrMore =>
        if !self.opts.literal_separator {
          // In this case, `*` and `?` can match a path
          // separator, which means this could reach outside
          // the basename.
          return None
        }
      RecursivePrefix | RecursiveSuffix | RecursiveZeroOrMore => return None
      // We *could* be a little smarter here, but either one
      // of these is going to prevent our literal optimizations
      // anyway, so give up.
      Class(..) | Alternates(_) => return None
    }
  }
  Some(self.tokens[start:])
}

///|
/// Returns the pattern as a literal if and only if the pattern exclusively
/// matches the basename of a file path *and* is a literal.
///
/// The basic format of these patterns is `**/{literal}`, where `{literal}`
/// does not contain a path separator.
fn Glob::basename_literal(self : Glob) -> String? {
  guard self.basename_tokens() is Some(tokens) else { return None }
  let lit = StringBuilder()
  for t in tokens {
    guard t is Literal(c) else { return None }
    lit.write_char(c)
  }
  Some(lit.to_string())
}

///|
/// Create a new builder for the pattern given.
///
/// The pattern is not compiled until `build` is called.
pub fn GlobBuilder::new(glob : String) -> GlobBuilder {
  { glob, opts: GlobOptions::default(), }
}

///|
/// Parses and builds the pattern.
pub fn GlobBuilder::build(self : GlobBuilder) -> Glob raise GlobError {
  let chars : Array[Char] = []
  for c in self.glob {
    chars.push(c)
  }
  let p : Parser = {
    glob: self.glob,
    alternates_stack: [],
    branches: [[]],
    chars,
    pos: 0,
    prev: None,
    cur: None,
    found_unclosed_class: false,
    opts: self.opts,
  }
  p.parse()
  if p.branches.is_empty() {
    // OK because of how the the branches/alternate_stack are managed.
    // If we end up here, then there *must* be a bug in the parser
    // somewhere.
    abort("unreachable")
  } else if p.branches.length() > 1 {
    raise GlobError(glob=Some(self.glob), kind=UnclosedAlternates)
  } else {
    let tokens = p.branches.unsafe_pop()
    {
      glob: self.glob,
      re: tokens_to_regex_with(tokens, self.opts),
      opts: self.opts,
      tokens,
    }
  }
}

///|
/// Toggle whether the pattern matches case insensitively or not.
///
/// This is disabled by default.
pub fn GlobBuilder::case_insensitive(
  self : GlobBuilder,
  yes : Bool,
) -> GlobBuilder {
  self.opts = { ..self.opts, case_insensitive: yes, }
  self
}

///|
/// Toggle whether a literal `/` is required to match a path separator.
///
/// By default this is false: `*` and `?` will match `/`.
pub fn GlobBuilder::literal_separator(
  self : GlobBuilder,
  yes : Bool,
) -> GlobBuilder {
  self.opts = { ..self.opts, literal_separator: yes, }
  self
}

///|
/// When enabled, a back slash (`\`) may be used to escape
/// special characters in a glob pattern. Additionally, this will
/// prevent `\` from being interpreted as a path separator on all
/// platforms.
///
/// This is enabled by default on platforms where `\` is not a
/// path separator and disabled by default on platforms where `\`
/// is a path separator.
pub fn GlobBuilder::backslash_escape(
  self : GlobBuilder,
  yes : Bool,
) -> GlobBuilder {
  self.opts = { ..self.opts, backslash_escape: yes, }
  self
}

///|
/// Toggle whether an empty pattern in a list of alternates is accepted.
///
/// For example, if this is set then the glob `foo{,.txt}` will match both
/// `foo` and `foo.txt`.
///
/// By default this is false.
pub fn GlobBuilder::empty_alternates(
  self : GlobBuilder,
  yes : Bool,
) -> GlobBuilder {
  self.opts = { ..self.opts, empty_alternates: yes, }
  self
}

///|
/// Toggle whether unclosed character classes are allowed. When allowed,
/// a `[` without a matching `]` is treated literally instead of resulting
/// in a parse error.
///
/// For example, if this is set then the glob `[abc` will be treated as the
/// literal string `[abc` instead of returning an error.
///
/// By default, this is false.
pub fn GlobBuilder::allow_unclosed_class(
  self : GlobBuilder,
  yes : Bool,
) -> GlobBuilder {
  self.opts = { ..self.opts, allow_unclosed_class: yes, }
  self
}

///|
/// Convert this pattern to a string that is guaranteed to be a valid
/// regular expression and will represent the matching semantics of this
/// glob pattern and the options given.
fn tokens_to_regex_with(tokens : Array[Token], options : GlobOptions) -> String {
  let re = StringBuilder()
  re.write_string("(?-u)")
  if options.case_insensitive {
    re.write_string("(?i)")
  }
  re.write_char('^')
  // Special case. If the entire glob is just `**`, then it should match
  // everything.
  if tokens.length() == 1 && tokens[0] is RecursivePrefix {
    re.write_string(".*")
    re.write_char('$')
    return re.to_string()
  }
  tokens_to_regex(options, tokens, re)
  re.write_char('$')
  re.to_string()
}

///|
fn tokens_to_regex(
  options : GlobOptions,
  tokens : ArrayView[Token],
  re : StringBuilder,
) -> Unit {
  for tok in tokens {
    match tok {
      Literal(c) => re.write_string(char_to_escaped_literal(c))
      Any =>
        if options.literal_separator {
          re.write_string("[^/]")
        } else {
          re.write_string(".")
        }
      ZeroOrMore =>
        if options.literal_separator {
          re.write_string("[^/]*")
        } else {
          re.write_string(".*")
        }
      RecursivePrefix => re.write_string("(?:/?|.*/)")
      RecursiveSuffix => re.write_string("/.*")
      RecursiveZeroOrMore => re.write_string("(?:/|/.*/)")
      Class(negated~, ranges~) => {
        re.write_char('[')
        if negated {
          re.write_char('^')
        }
        for r in ranges {
          if r.0 == r.1 {
            // Not strictly necessary, but nicer to look at.
            re.write_string(char_to_escaped_literal(r.0))
          } else {
            re.write_string(char_to_escaped_literal(r.0))
            re.write_char('-')
            re.write_string(char_to_escaped_literal(r.1))
          }
        }
        re.write_char(']')
      }
      Alternates(patterns) => {
        let parts : Array[String] = []
        for pat in patterns {
          let altre = StringBuilder()
          tokens_to_regex(options, pat, altre)
          let altre = altre.to_string()
          if !altre.is_empty() || options.empty_alternates {
            parts.push(altre)
          }
        }
        // It is possible to have an empty set in which case the
        // resulting alternation '()' would be an error.
        if !parts.is_empty() {
          re.write_string("(?:")
          re.write_string(parts.join("|"))
          re.write_char(')')
        }
      }
    }
  }
}

///|
/// Convert a Unicode scalar value to an escaped string suitable for use as
/// a literal in a non-Unicode regex.
fn char_to_escaped_literal(c : Char) -> String {
  bytes_to_escaped_literal(@utf8.encode(String::make(1, c)))
}

///|
/// Converts an arbitrary sequence of bytes to a UTF-8 string. All non-ASCII
/// code units are converted to their escaped form.
fn bytes_to_escaped_literal(bs : Bytes) -> String {
  let s = StringBuilder()
  for b in bs {
    if b <= 0x7F {
      let c = b.to_int().unsafe_to_char()
      if @syntax.is_meta_character(c) {
        s.write_char('\\')
      }
      s.write_char(c)
    } else {
      s.write_string("\\x")
      s.write_char(hex_digit(b.to_int() >> 4))
      s.write_char(hex_digit(b.to_int() & 0xF))
    }
  }
  s.to_string()
}

///|
fn hex_digit(n : Int32) -> Char {
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('a'.to_int() + n - 10).unsafe_to_char()
  }
}

///|
priv struct Parser {
  /// The glob to parse.
  glob : String
  /// Marks the index in `stack` where the alternation started.
  alternates_stack : Array[Int32]
  /// The set of active alternation branches being parsed.
  /// Tokens are added to the end of the last one.
  branches : Array[Array[Token]]
  /// The characters of the glob pattern to parse.
  chars : Array[Char]
  /// The index of the next character to read from `chars`.
  mut pos : Int32
  /// The previous character seen.
  mut prev : Char?
  /// The current character.
  mut cur : Char?
  /// Whether we failed to find a closing `]` for a character
  /// class. This can only be true when `GlobOptions::allow_unclosed_class`
  /// is enabled. When enabled, it is impossible to ever parse another
  /// character class with this glob. That's because classes cannot be
  /// nested *and* the only way this happens is when there is never a `]`.
  ///
  /// We track this state so that we don't end up spending quadratic time
  /// trying to parse something like `[[[[[[[[[[[[[[[[[[[[[[[...`.
  mut found_unclosed_class : Bool
  /// Glob options, which may influence parsing.
  opts : GlobOptions
}

///|
fn Parser::error(self : Parser, kind : ErrorKind) -> GlobError {
  GlobError(glob=Some(self.glob), kind~)
}

///|
fn Parser::parse(self : Parser) -> Unit raise GlobError {
  while self.bump() is Some(c) {
    match c {
      '?' => self.push_token(Any)
      '*' => self.parse_star()
      '[' if !self.found_unclosed_class => self.parse_class()
      '{' => self.push_alternate()
      '}' => self.pop_alternate()
      ',' => self.parse_comma()
      '\\' => self.parse_backslash()
      c => self.push_token(Literal(c))
    }
  }
}

///|
fn Parser::push_alternate(self : Parser) -> Unit {
  self.alternates_stack.push(self.branches.length())
  self.branches.push([])
}

///|
fn Parser::pop_alternate(self : Parser) -> Unit raise GlobError {
  guard self.alternates_stack.pop() is Some(start) else {
    raise self.error(UnopenedAlternates)
  }
  guard! start <= self.branches.length()
  let alts = Alternates(self.branches.drain(start, self.branches.length()))
  self.push_token(alts)
}

///|
fn Parser::push_token(self : Parser, tok : Token) -> Unit raise GlobError {
  guard self.branches.last() is Some(pat) else {
    raise self.error(UnopenedAlternates)
  }
  pat.push(tok)
}

///|
fn Parser::pop_token(self : Parser) -> Token raise GlobError {
  guard self.branches.last() is Some(pat) else {
    raise self.error(UnopenedAlternates)
  }
  pat.unsafe_pop()
}

///|
fn Parser::have_tokens(self : Parser) -> Bool raise GlobError {
  match self.branches.last() {
    None => raise self.error(UnopenedAlternates)
    Some(pat) => !pat.is_empty()
  }
}

///|
fn Parser::parse_comma(self : Parser) -> Unit raise GlobError {
  // If we aren't inside a group alternation, then don't
  // treat commas specially. Otherwise, we need to start
  // a new alternate branch.
  if self.alternates_stack.is_empty() {
    self.push_token(Literal(','))
  } else {
    self.branches.push([])
  }
}

///|
fn Parser::parse_backslash(self : Parser) -> Unit raise GlobError {
  if self.opts.backslash_escape {
    match self.bump() {
      None => raise self.error(DanglingEscape)
      Some(c) => self.push_token(Literal(c))
    }
  } else if is_separator('\\') {
    // Normalize all patterns to use / as a separator.
    self.push_token(Literal('/'))
  } else {
    self.push_token(Literal('\\'))
  }
}

///|
fn Parser::parse_star(self : Parser) -> Unit raise GlobError {
  let prev = self.prev
  if self.peek() != Some('*') {
    self.push_token(ZeroOrMore)
    return
  }
  guard! self.bump() == Some('*')
  if !self.have_tokens() {
    if !none_or_separator(self.peek()) {
      self.push_token(ZeroOrMore)
      self.push_token(ZeroOrMore)
    } else {
      self.push_token(RecursivePrefix)
      guard! none_or_separator(self.bump())
    }
    return
  }
  if !(prev is Some(p) && is_separator(p)) {
    if self.branches.length() <= 1 || (prev != Some(',') && prev != Some('{')) {
      self.push_token(ZeroOrMore)
      self.push_token(ZeroOrMore)
      return
    }
  }
  let is_suffix = match self.peek() {
    None => {
      guard! self.bump() is None
      true
    }
    Some(',' | '}') if self.branches.length() >= 2 => true
    Some(c) if is_separator(c) => {
      guard! self.bump() is Some(c) && is_separator(c)
      false
    }
    _ => {
      self.push_token(ZeroOrMore)
      self.push_token(ZeroOrMore)
      return
    }
  }
  match self.pop_token() {
    RecursivePrefix => self.push_token(RecursivePrefix)
    RecursiveSuffix => self.push_token(RecursiveSuffix)
    _ =>
      if is_suffix {
        self.push_token(RecursiveSuffix)
      } else {
        self.push_token(RecursiveZeroOrMore)
      }
  }
}

///|
fn none_or_separator(c : Char?) -> Bool {
  match c {
    None => true
    Some(c) => is_separator(c)
  }
}

///|
fn Parser::parse_class(self : Parser) -> Unit raise GlobError {
  // Save parser state for potential rollback to literal '[' parsing.
  let saved_pos = self.pos
  let saved_prev = self.prev
  let saved_cur = self.cur
  fn add_to_last_range(
    glob : String,
    ranges : Array[(Char, Char)],
    add : Char,
  ) -> Unit raise GlobError {
    let i = ranges.length() - 1
    let r = (ranges[i].0, add)
    ranges[i] = r
    if r.1 < r.0 {
      raise GlobError(glob=Some(glob), kind=InvalidRange(r.0, r.1))
    }
  }

  let ranges : Array[(Char, Char)] = []
  let negated = match self.peek() {
    Some('!' | '^') => {
      guard! self.bump() is Some('!' | '^')
      true
    }
    _ => false
  }
  let mut first = true
  let mut in_range = false
  for ;; {
    guard self.bump() is Some(c) else {
      if self.opts.allow_unclosed_class {
        self.pos = saved_pos
        self.cur = saved_cur
        self.prev = saved_prev
        self.found_unclosed_class = true
        self.push_token(Literal('['))
        return
      } else {
        raise self.error(UnclosedClass)
      }
    }
    match c {
      ']' => if first { ranges.push((']', ']')) } else { break }
      '-' =>
        if first {
          ranges.push(('-', '-'))
        } else if in_range {
          // invariant: in_range is only set when there is
          // already at least one character seen.
          add_to_last_range(self.glob, ranges, '-')
          in_range = false
        } else {
          guard! !ranges.is_empty()
          in_range = true
        }
      c => {
        if in_range {
          // invariant: in_range is only set when there is
          // already at least one character seen.
          add_to_last_range(self.glob, ranges, c)
        } else {
          ranges.push((c, c))
        }
        in_range = false
      }
    }
    first = false
  }
  if in_range {
    // Means that the last character in the class was a '-', so add
    // it as a literal.
    ranges.push(('-', '-'))
  }
  self.push_token(Class(negated~, ranges~))
}

///|
fn Parser::bump(self : Parser) -> Char? {
  self.prev = self.cur
  if self.pos < self.chars.length() {
    self.cur = Some(self.chars[self.pos])
    self.pos += 1
  } else {
    self.cur = None
  }
  self.cur
}

///|
fn Parser::peek(self : Parser) -> Char? {
  self.chars.get(self.pos)
}
