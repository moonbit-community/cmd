///|
fn p(pattern : String) -> String {
  @syntax.parse(pattern).to_string() catch {
    e => e.to_string()
  }
}

///|
fn pb(pattern : String) -> String {
  @syntax.parse(pattern, config={
    ..@syntax.ParseConfig::default(),
    utf8: false,
  }).to_string() catch {
    e => e.to_string()
  }
}

///|
test "basic translate" {
  inspect(p("abc"), content="abc")
  inspect(p("a|b|c"), content="[a-c]")
  inspect(p("a+b*?c?"), content="a+b*?c?")
  inspect(p("(?i)a"), content="[Aa]")
  inspect(p("(?i)k"), content="[Kk\u{212a}]")
  inspect(p("(foo)(?P<n>bar)"), content="(foo)(?P<n>bar)")
  inspect(p("a{2,3}"), content="a{2,3}")
  inspect(p("^a$"), content="\\Aa\\z")
  inspect(p("(?m)^a$"), content="(?m:^)a(?m:$)")
  inspect(p("[a-c&&b-z]"), content="[b-c]")
  inspect(p("[[:alpha:]]"), content="[A-Za-z]")
  inspect(p("(?-u)\\w"), content="(?-u:[0-9A-Z_a-z])")
  inspect(p("foo|foobar"), content="foo|foobar")
  inspect(p("a+c|a+d"), content="a+[c-d]")
  inspect(p("\\x{61}"), content="a")
  inspect(p("[^a]"), content="[\\x00-`b-\u{10ffff}]")
}

///|
test "bytes" {
  inspect(pb("(?-u:\\xFF)"), content="(?-u:\\xFF)")
  inspect(pb("(?-u:.)"), content="(?-u:[\\x00-\\x09\\x0B-\\xFF])")
  inspect(pb("."), content="[\\x00-\\x09\\x0B-\u{10ffff}]")
}

///|
test "errors" {
  inspect(
    p("(foo"),
    content=(
      #|regex parse error:
      #|    (foo
      #|    ^
      #|error: unclosed group
    ),
  )
  inspect(
    p("a)"),
    content=(
      #|regex parse error:
      #|    a)
      #|     ^
      #|error: unopened group
    ),
  )
  inspect(
    p("\\1"),
    content=(
      #|regex parse error:
      #|    \1
      #|    ^^
      #|error: backreferences are not supported
    ),
  )
  inspect(
    p("[a"),
    content=(
      #|regex parse error:
      #|    [a
      #|    ^
      #|error: unclosed character class
    ),
  )
  inspect(
    p("*"),
    content=(
      #|regex parse error:
      #|    *
      #|    ^
      #|error: repetition operator missing expression
    ),
  )
  inspect(
    p("(?P<a>x)(?P<a>y)"),
    content=(
      #|regex parse error:
      #|    (?P<a>x)(?P<a>y)
      #|        ^       ^
      #|error: duplicate capture group name
    ),
  )
  inspect(
    p("\\p{Foo}"),
    content=(
      #|regex parse error:
      #|    \p{Foo}
      #|    ^^^^^^^
      #|error: Unicode property not found
    ),
  )
  inspect(
    p("x{5,2}"),
    content=(
      #|regex parse error:
      #|    x{5,2}
      #|     ^^^^^
      #|error: invalid repetition count range, the start must be <= the end
    ),
  )
  inspect(
    p("(?=a)"),
    content=(
      #|regex parse error:
      #|    (?=a)
      #|    ^^^
      #|error: look-around, including look-ahead and look-behind, is not supported
    ),
  )
}
