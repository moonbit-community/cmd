// Helpers mirroring the macros and helper functions of the Rust
// `glob.rs` test module.

///|
fn build(
  pat : String,
  casei? : Bool,
  litsep? : Bool,
  bsesc? : Bool,
  ealtre? : Bool,
  unccls? : Bool,
) -> Glob raise GlobError {
  let builder = GlobBuilder::new(pat)
  if casei is Some(casei) {
    builder.case_insensitive(casei) |> ignore
  }
  if litsep is Some(litsep) {
    builder.literal_separator(litsep) |> ignore
  }
  if bsesc is Some(bsesc) {
    builder.backslash_escape(bsesc) |> ignore
  }
  if ealtre is Some(ealtre) {
    builder.empty_alternates(ealtre) |> ignore
  }
  if unccls is Some(unccls) {
    builder.allow_unclosed_class(unccls) |> ignore
  }
  builder.build()
}

///|
fn glob_err_kind(pat : String) -> ErrorKind raise {
  try Glob::new(pat) catch {
    err => err.kind()
  } noraise {
    _ => fail("expected glob \{pat} to fail to parse")
  }
}

///|
#callsite(autofill(loc))
fn assert_matches(
  pat : String,
  path : String,
  casei? : Bool,
  litsep? : Bool,
  bsesc? : Bool,
  ealtre? : Bool,
  loc~ : SourceLoc,
) -> Unit raise {
  let pat = build(pat, casei?, litsep?, bsesc?, ealtre?)
  let matcher = pat.compile_matcher()
  let strategic = pat.compile_strategic_matcher()
  let set = GlobSetBuilder::new().add(pat).build()
  assert_true(matcher.is_match(path), msg="matcher: \{pat} vs \{path}", loc~)
  assert_true(
    strategic.is_match(path),
    msg="strategic: \{pat} vs \{path}",
    loc~,
  )
  assert_true(set.is_match(path), msg="set: \{pat} vs \{path}", loc~)
}

///|
#callsite(autofill(loc))
fn assert_nmatches(
  pat : String,
  path : String,
  casei? : Bool,
  litsep? : Bool,
  bsesc? : Bool,
  ealtre? : Bool,
  loc~ : SourceLoc,
) -> Unit raise {
  let pat = build(pat, casei?, litsep?, bsesc?, ealtre?)
  let matcher = pat.compile_matcher()
  let strategic = pat.compile_strategic_matcher()
  let set = GlobSetBuilder::new().add(pat).build()
  assert_false(matcher.is_match(path), msg="matcher: \{pat} vs \{path}", loc~)
  assert_false(
    strategic.is_match(path),
    msg="strategic: \{pat} vs \{path}",
    loc~,
  )
  assert_false(set.is_match(path), msg="set: \{pat} vs \{path}", loc~)
}

///|
fn Glob::basename_tokens_array(self : Glob) -> Array[Token]? {
  self.basename_tokens().map(ts => ts.to_owned())
}

///|
fn class(s : Char, e : Char) -> Token {
  Class(negated=false, ranges=[(s, e)])
}

///|
fn classn(s : Char, e : Char) -> Token {
  Class(negated=true, ranges=[(s, e)])
}

///|
fn rclass(ranges : Array[(Char, Char)]) -> Token {
  Class(negated=false, ranges~)
}

///|
fn rclassn(ranges : Array[(Char, Char)]) -> Token {
  Class(negated=true, ranges~)
}
