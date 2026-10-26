///|
/// Configuration for building a regex matcher.
pub(all) struct Config {
  case_insensitive : Bool
  case_smart : Bool
  multi_line : Bool
  dot_matches_new_line : Bool
  swap_greed : Bool
  ignore_whitespace : Bool
  unicode : Bool
  octal : Bool
  size_limit : Int32
  dfa_size_limit : Int32
  nest_limit : Int32
  line_terminator : @matcher.LineTerminator?
  ban : Byte?
  crlf : Bool
  word : Bool
  fixed_strings : Bool
  whole_line : Bool
} derive(Debug)

///|
pub fn Config::default() -> Config {
  {
    case_insensitive: false,
    case_smart: false,
    multi_line: false,
    dot_matches_new_line: false,
    swap_greed: false,
    ignore_whitespace: false,
    unicode: true,
    octal: false,
    size_limit: 100 * (1 << 20),
    dfa_size_limit: 1000 * (1 << 20),
    nest_limit: 250,
    line_terminator: None,
    ban: None,
    crlf: false,
    word: false,
    fixed_strings: false,
    whole_line: false,
  }
}

///|
fn Config::is_case_insensitive(self : Config, analysis : AstAnalysis) -> Bool {
  if self.case_insensitive {
    return true
  }
  if !self.case_smart {
    return false
  }
  analysis.any_literal && !analysis.any_uppercase
}

///|
fn has_line_terminator(
  lineterm : @matcher.LineTerminator,
  lit : String,
) -> Bool {
  let bytes = @utf8.encode(lit)
  if lineterm.is_crlf() {
    bytes.iter().any(b => b == b'\r' || b == b'\n')
  } else {
    bytes.iter().any(b => b == lineterm.as_byte())
  }
}

///|
fn Config::is_fixed_strings(self : Config, patterns : Array[String]) -> Bool {
  if self.case_insensitive || self.case_smart {
    return false
  }
  if self.fixed_strings {
    if self.line_terminator is Some(lt) {
      for p in patterns {
        if has_line_terminator(lt, p) {
          return false
        }
      }
    }
    return true
  }
  for p in patterns {
    for c in p {
      if @syntax.is_meta_character(c) {
        return false
      }
    }
    if self.line_terminator is Some(lt) && has_line_terminator(lt, p) {
      return false
    }
  }
  true
}

///|
/// A regex HIR together with the configuration used to build it.
priv struct ConfiguredHIR {
  config : Config
  hir : @syntax.Hir
}

///|
fn ConfiguredHIR::new(
  config : Config,
  patterns : Array[String],
) -> ConfiguredHIR raise GrepRegexError {
  let hir = if config.is_fixed_strings(patterns) {
    @syntax.Hir::alternation(
      patterns.map(p => @syntax.Hir::literal(@utf8.encode(p))),
    )
  } else {
    let alts = patterns.map(p => {
      if config.fixed_strings {
        "(?:\{@syntax.escape(p)})"
      } else {
        "(?:\{p})"
      }
    })
    let pattern = alts.join("|")
    let ast = @syntax.parse_ast(pattern, config={
      ignore_whitespace: config.ignore_whitespace,
      nest_limit: config.nest_limit,
      octal: config.octal,
      empty_min_range: false,
    }) catch {
      e => raise GrepRegexError(Regex(e.to_string()))
    }
    let analysis = AstAnalysis::from_ast(ast)
    let mut hir = @syntax.translate(pattern, ast, config={
      utf8: false,
      line_terminator: '\n',
      case_insensitive: config.is_case_insensitive(analysis),
      multi_line: config.multi_line,
      dot_matches_new_line: config.dot_matches_new_line,
      crlf: config.crlf,
      swap_greed: config.swap_greed,
      unicode: config.unicode,
    }) catch {
      e => raise GrepRegexError(Regex(e.to_string()))
    }
    if config.ban is Some(byte) {
      ban_check(hir, byte)
    }
    hir = match config.line_terminator {
      None => hir
      Some(lt) => strip_from_match(hir, lt)
    }
    hir
  }
  { config, hir, }
}

///|
fn ConfiguredHIR::to_regex(
  self : ConfiguredHIR,
) -> @regex.Regex raise GrepRegexError {
  @regex.Regex::from_hir(self.hir, config={
    nfa_size_limit: Some(self.config.size_limit),
    dfa_state_limit: 10000,
  }) catch {
    TooBig(limit) =>
      raise GrepRegexError(
        Regex("compiled regex exceeds size limit of \{limit}"),
      )
    e => raise GrepRegexError(Regex(e.to_string()))
  }
}

///|
fn ConfiguredHIR::line_terminator(
  self : ConfiguredHIR,
) -> @matcher.LineTerminator? {
  if self.hir.props.look_set.contains_anchor_haystack() {
    None
  } else {
    self.config.line_terminator
  }
}

///|
fn ConfiguredHIR::into_whole_line(self : ConfiguredHIR) -> ConfiguredHIR {
  let (s, e) = if self.config.crlf {
    (@syntax.Look::StartCRLF, @syntax.Look::EndCRLF)
  } else {
    (StartLF, EndLF)
  }
  let hir = @syntax.Hir::concat([
    @syntax.Hir::look(s),
    self.hir,
    @syntax.Hir::look(e),
  ])
  { config: self.config, hir, }
}

///|
fn ConfiguredHIR::into_word(self : ConfiguredHIR) -> ConfiguredHIR {
  let (s, e) = if self.config.unicode {
    (@syntax.Look::WordStartHalfUnicode, @syntax.Look::WordEndHalfUnicode)
  } else {
    (WordStartHalfAscii, WordEndHalfAscii)
  }
  let hir = @syntax.Hir::concat([
    @syntax.Hir::look(s),
    self.hir,
    @syntax.Hir::look(e),
  ])
  { config: self.config, hir, }
}
