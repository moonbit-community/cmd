///|
/// Compile command search rules once, before opening any input. The matcher
/// retains execution data only; option precedence belongs to ExecutionPlan.
fn SearchMatcher::new(
  patterns : Array[String],
  case_mode~ : CaseMode = Sensitive,
  boundary~ : BoundaryMode? = None,
  multi_line~ : Bool = false,
  dot_matches_new_line~ : Bool = false,
  unicode~ : Bool = true,
  fixed_strings~ : Bool = false,
  crlf~ : Bool = false,
  line_terminator~ : @matcher.LineTerminator? = None,
  ban~ : Byte? = None,
  size_limit~ : Int32 = 100 * (1 << 20),
) -> SearchMatcher raise SearchPatternError {
  let mut hir = if direct_literals(
      patterns, case_mode, fixed_strings, line_terminator,
    ) {
    @syntax.Hir::alternation(
      patterns.map(p => @syntax.Hir::literal(@utf8.encode(p))),
    )
  } else {
    let pattern = patterns
      .map(p => {
        if fixed_strings {
          "(?:\{@syntax.escape(p)})"
        } else {
          "(?:\{p})"
        }
      })
      .join("|")
    let ast = @syntax.parse_ast(pattern, config={
      ignore_whitespace: false,
      nest_limit: 250,
      octal: false,
      empty_min_range: false,
    }) catch {
      e => raise SearchPatternError::Regex(e.to_string())
    }
    let analysis = AstAnalysis::from_ast(ast)
    let mut hir = @syntax.translate(pattern, ast, config={
      utf8: false,
      line_terminator: '\n',
      case_insensitive: match case_mode {
        Sensitive => false
        Insensitive => true
        Smart => analysis.any_literal && !analysis.any_uppercase
      },
      multi_line,
      dot_matches_new_line,
      crlf,
      swap_greed: false,
      unicode,
    }) catch {
      e => raise SearchPatternError::Regex(e.to_string())
    }
    if ban is Some(byte) {
      ban_check(hir, byte)
    }
    if line_terminator is Some(lt) {
      hir = strip_from_match(hir, lt)
    }
    hir
  }
  let edges : (@syntax.Look, @syntax.Look)? = match boundary {
    Some(Line) =>
      Some(if crlf { (StartCRLF, EndCRLF) } else { (StartLF, EndLF) })
    Some(Word) =>
      Some(
        if unicode {
          (WordStartHalfUnicode, WordEndHalfUnicode)
        } else {
          (WordStartHalfAscii, WordEndHalfAscii)
        },
      )
    None => None
  }
  if edges is Some((start, end)) {
    hir = @syntax.Hir::concat([
      @syntax.Hir::look(start),
      hir,
      @syntax.Hir::look(end),
    ])
  }
  let regex = @regex.Regex::from_hir(hir, config={
    nfa_size_limit: Some(size_limit),
    dfa_state_limit: 10000,
  }) catch {
    TooBig(limit) =>
      raise SearchPatternError::Regex(
        "compiled regex exceeds size limit of \{limit}",
      )
    e => raise SearchPatternError::Regex(e.to_string())
  }
  let non_matching = non_matching_bytes(hir)
  let fast_line_regex = if line_terminator is None ||
    (regex.is_accelerated() && !hir.props.look_set.contains_word_unicode()) ||
    hir.props.alternation_literal {
    None
  } else {
    match hir.inner_literals().literals() {
      Some(lits) if lits.length() > 0 => {
        let inner = @syntax.Hir::alternation(
          lits.map(l => @syntax.Hir::literal(l.bytes)),
        )
        Some(
          @regex.Regex::from_hir(inner) catch {
            e => raise SearchPatternError::Regex(e.to_string())
          },
        )
      }
      _ => None
    }
  }
  {
    regex,
    fast_line_regex,
    non_matching_bytes: non_matching,
    line_terminator: if hir.props.look_set.contains_anchor_haystack() {
      None
    } else {
      line_terminator
    },
  }
}

///|
fn direct_literals(
  patterns : Array[String],
  case_mode : CaseMode,
  fixed_strings : Bool,
  line_terminator : @matcher.LineTerminator?,
) -> Bool {
  if case_mode != Sensitive {
    return false
  }
  for pattern in patterns {
    if !fixed_strings && pattern.iter().any(@syntax.is_meta_character) {
      return false
    }
    if line_terminator is Some(lt) {
      for byte in @utf8.encode(pattern) {
        if byte == lt.as_byte() || (lt.is_crlf() && byte == b'\r') {
          return false
        }
      }
    }
  }
  true
}
