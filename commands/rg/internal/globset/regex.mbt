///|
/// The approximate NFA size limit used when compiling glob regexes. This
/// mirrors the 10MB limit used by the Rust implementation.
let nfa_size_limit : Int32 = 10 * (1 << 20)

///|
/// Parses `pat` with the syntax configuration used for all glob regexes:
/// matching is done on arbitrary bytes and `.` matches `\n`.
fn parse_glob_regex(pat : String) -> @syntax.Hir raise @syntax.SyntaxError {
  @syntax.parse(pat, config={
    ..@syntax.ParseConfig::default(),
    utf8: false,
    dot_matches_new_line: true,
  })
}

///|
/// Compiles the given (glob-derived) regex pattern.
fn new_regex(pat : String) -> @regex.Regex raise GlobError {
  let hir = parse_glob_regex(pat) catch {
    e => raise GlobError(glob=Some(pat), kind=Regex(e.to_string()))
  }
  @regex.Regex::from_hir(hir, config={
    ..@regex.RegexConfig::default(),
    nfa_size_limit: Some(nfa_size_limit),
  }) catch {
    e => raise GlobError(glob=Some(pat), kind=Regex(e.to_string()))
  }
}

///|
/// Compiles a single regex that matches if any of the given patterns match.
/// Errors are reported without an associated glob, like Rust's
/// `new_regex_set`.
fn new_regex_any(pats : ArrayView[String]) -> @regex.Regex raise GlobError {
  let combined = StringBuilder()
  for i, pat in pats {
    if i > 0 {
      combined.write_char('|')
    }
    combined.write_string("(?:")
    combined.write_string(pat)
    combined.write_char(')')
  }
  let combined = combined.to_string()
  let hir = parse_glob_regex(combined) catch {
    e => raise GlobError(glob=None, kind=Regex(e.to_string()))
  }
  @regex.Regex::from_hir(hir, config={
    ..@regex.RegexConfig::default(),
    nfa_size_limit: Some(nfa_size_limit),
  }) catch {
    e => raise GlobError(glob=None, kind=Regex(e.to_string()))
  }
}

///|
/// Reports whether `re` matches anywhere in `hay`.
fn regex_is_match(re : @regex.Regex, hay : FixedArray[Byte]) -> Bool {
  let n = hay.length()
  re.is_match_at(hay, 0, n, 0, n)
}
