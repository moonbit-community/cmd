///|
fn analysis(pattern : String) -> (Bool, Bool) {
  let ast = @syntax.parse_ast(pattern) catch { e => abort(e.to_string()) }
  let a = AstAnalysis::from_ast(ast)
  (a.any_uppercase, a.any_literal)
}

///|
test "ast analysis" {
  debug_inspect(analysis(""), content="(false, false)")
  debug_inspect(analysis("foo"), content="(false, true)")
  debug_inspect(analysis("Foo"), content="(true, true)")
  debug_inspect(analysis("foO"), content="(true, true)")
  debug_inspect(analysis("foo\\\\"), content="(false, true)")
  debug_inspect(analysis("foo\\w"), content="(false, true)")
  debug_inspect(analysis("foo\\S"), content="(false, true)")
  debug_inspect(analysis("foo\\p{Ll}"), content="(false, true)")
  debug_inspect(analysis("foo[a-z]"), content="(false, true)")
  debug_inspect(analysis("foo[A-Z]"), content="(true, true)")
  debug_inspect(analysis("foo[\\S\\t]"), content="(false, true)")
  debug_inspect(analysis("foo\\\\S"), content="(true, true)")
  debug_inspect(analysis("\\p{Ll}"), content="(false, false)")
  debug_inspect(analysis("aBc\\w"), content="(true, true)")
  debug_inspect(analysis("a\\u0061"), content="(false, true)")
}

///|
fn roundtrip_lt(
  pattern : String,
  lt : @matcher.LineTerminator,
) -> Result[String, String] {
  let hir = @syntax.parse(pattern) catch { e => abort(e.to_string()) }
  let h = strip_from_match(hir, lt) catch { e => return Err(e.to_string()) }
  Ok(h.to_string())
}

///|
fn roundtrip(pattern : String, b : Byte) -> String {
  match roundtrip_lt(pattern, Byte(b)) {
    Ok(s) => s
    Err(e) => "ERR: " + e
  }
}

///|
fn roundtrip_crlf(pattern : String) -> String {
  match roundtrip_lt(pattern, CRLF) {
    Ok(s) => s
    Err(e) => "ERR: " + e
  }
}

///|
test "strip" {
  inspect(roundtrip("[a\\n]", b'\n'), content="a")
  inspect(roundtrip("[a\\n]", b'a'), content="\\x0A")
  inspect(roundtrip_crlf("[a\\n]"), content="a")
  inspect(roundtrip_crlf("[a\\r]"), content="a")
  inspect(roundtrip_crlf("[a\\r\\n]"), content="a")
  inspect(roundtrip("(?-u)\\s", b'a'), content="(?-u:[\\x09-\\x0D ])")
  inspect(roundtrip("(?-u)\\s", b'\n'), content="(?-u:[\\x09\\x0B-\\x0D ])")
  for
    p in [
      "\\n", "abc\\n", "\\nabc", "abc\\nxyz", "\\x0A", "\\u000A", "\\U0000000A",
      "\\u{A}", "\n",
    ] {
    inspect(roundtrip(p, b'\n').has_prefix("ERR"), content="true")
  }
  inspect(
    roundtrip("\\n", b'\n'),
    content="ERR: the literal \"\\n\" is not allowed in a regex",
  )
}

///|
fn ban(pattern : String, b : Byte) -> Bool {
  let hir = @syntax.parse(pattern) catch { e => abort(e.to_string()) }
  ban_check(hir, b) catch {
    _ => return true
  }
  false
}

///|
test "ban" {
  for
    p in [
      "\\x00", "a\\x00", "\\x00b", "a\\x00b", "\\x00|ab", "ab|\\x00", "\\x00?", "(\\x00)",
      "[\\x00]", "[^[^\\x00]]",
    ] {
    inspect(ban(p, b'\x00'), content="true")
  }
  inspect(ban("[^\\x00]", b'\x00'), content="false")
  inspect(ban("[\\x00a]", b'\x00'), content="false")
}

///|
fn sparse(pattern : String) -> Array[Int32] {
  let hir = @syntax.parse(pattern, config={
    ..@syntax.ParseConfig::default(),
    utf8: false,
  }) catch {
    e => abort(e.to_string())
  }
  let set = non_matching_bytes(hir)
  let out = []
  for b in 0..<256 {
    if set.contains(b.to_byte()) {
      out.push(b)
    }
  }
  out
}

///|
fn sparse_except(except : Array[Int32]) -> Array[Int32] {
  let out = []
  for b in 0..<256 {
    if !except.contains(b) {
      out.push(b)
    }
  }
  out
}

///|
test "non matching bytes" {
  debug_inspect(
    sparse("."),
    content="[10, 192, 193, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255]",
  )
  debug_inspect(
    sparse("(?s)."),
    content="[192, 193, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255]",
  )
  debug_inspect(sparse("(?-u)."), content="[10]")
  debug_inspect(sparse("(?s-u)."), content="[]")
  assert_eq(sparse("a"), sparse_except(['a']))
  assert_eq(sparse("☃"), sparse_except([0xE2, 0x98, 0x83]))
  assert_eq(sparse("\\xFF"), sparse_except([0xC3, 0xBF]))
  assert_eq(sparse("(?-u)\\xFF"), sparse_except([0xFF]))
  for p in ["^", "$", "\\A", "\\z", "(?m)^", "(?m)$"] {
    assert_eq(sparse(p), sparse_except(['\n']))
  }
}
