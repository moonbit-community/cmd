///|
fn show_seq(seq : @syntax.Seq) -> String {
  match seq.literals() {
    None => "[inf]"
    Some(lits) =>
      "[" +
      lits
      .map(l => {
        (if l.exact { "E(" } else { "I(" }) + @utf8.decode_lossy(l.bytes) + ")"
      })
      .join(", ") +
      "]"
  }
}

///|
fn e(pattern : String) -> String {
  let hir = @syntax.parse(pattern, config={
    ..@syntax.ParseConfig::default(),
    utf8: false,
  }) catch {
    err => abort(err.to_string())
  }
  show_seq(InnerExtractor::new().extract_untagged(hir))
}

///|
test "inner literals 0" {
  inspect(e("foo"), content="[E(foo)]")
}

///|
test "inner literals 1" {
  inspect(e("[a-z]foo[a-z]"), content="[I(foo)]")
}

///|
test "inner literals 2" {
  inspect(e("[a-z](foo)(bar)[a-z]"), content="[I(foobar)]")
}

///|
test "inner literals 3" {
  inspect(e("[a-z]([a-z]foo)(bar[a-z])[a-z]"), content="[I(foo)]")
}

///|
test "inner literals 4" {
  inspect(e("[a-z]([a-z]foo)([a-z]foo)[a-z]"), content="[I(foo)]")
}

///|
test "inner literals 5" {
  inspect(e("(\\d{1,3}\\.){3}\\d{1,3}"), content="[I(.)]")
}

///|
test "inner literals 6" {
  inspect(e("[a-z]([a-z]foo){3}[a-z]"), content="[I(foo)]")
}

///|
test "inner literals 7" {
  inspect(e("[a-z](foo[a-z]){3}[a-z]"), content="[I(foo)]")
}

///|
test "inner literals 8" {
  inspect(e("[a-z]([a-z]foo[a-z]){3}[a-z]"), content="[I(foo)]")
}

///|
test "inner literals 9" {
  inspect(e("[a-z]([a-z]foo){3}(bar[a-z]){3}[a-z]"), content="[I(foo)]")
}

///|
test "inner literals 10" {
  inspect(e("[a-z]+(ab|cd|ef)[a-z]+hiya[a-z]+"), content="[I(hiya)]")
}

///|
test "inner literals 11" {
  inspect(
    e("[a-z]+(abc|def|ghi)[a-z]+hiya[a-z]+"),
    content="[I(abc), I(def), I(ghi)]",
  )
}

///|
test "inner literals 12" {
  inspect(e("a"), content="[E(a)]")
}

///|
test "inner literals 13" {
  inspect(e("aaaaa"), content="[E(aaaaa)]")
}

///|
test "inner literals 14" {
  inspect(e("(?i-u)a"), content="[E(A), E(a)]")
}

///|
test "inner literals 15" {
  inspect(e("(?i-u)ab"), content="[E(AB), E(Ab), E(aB), E(ab)]")
}

///|
test "inner literals 16" {
  inspect(e("ab(?i-u)c"), content="[E(abC), E(abc)]")
}

///|
test "inner literals 17" {
  inspect(e("(?-u:\\xFF)"), content="[inf]")
}

///|
test "inner literals 18" {
  inspect(e("Z"), content="[E(Z)]")
}

///|
test "inner literals 19" {
  inspect(e("☃"), content="[E(☃)]")
}

///|
test "inner literals 20" {
  inspect(e("(?i)☃"), content="[E(☃)]")
}

///|
test "inner literals 21" {
  inspect(e("☃☃☃☃☃"), content="[E(☃☃☃☃☃)]")
}

///|
test "inner literals 22" {
  inspect(e("Δ"), content="[E(Δ)]")
}

///|
test "inner literals 23" {
  inspect(e("δ"), content="[E(δ)]")
}

///|
test "inner literals 24" {
  inspect(e("(?i)Δ"), content="[E(Δ), E(δ)]")
}

///|
test "inner literals 25" {
  inspect(e("(?i)δ"), content="[E(Δ), E(δ)]")
}

///|
test "inner literals 26" {
  inspect(e("(?i)S"), content="[E(S), E(s), E(ſ)]")
}

///|
test "inner literals 27" {
  inspect(e("(?i)s"), content="[E(S), E(s), E(ſ)]")
}

///|
test "inner literals 28" {
  inspect(e("(?i)ſ"), content="[E(S), E(s), E(ſ)]")
}

///|
test "inner literals 29" {
  inspect(e("[abc]"), content="[E(a), E(b), E(c)]")
}

///|
test "inner literals 30" {
  inspect(e("a[123]b"), content="[E(a1b), E(a2b), E(a3b)]")
}

///|
test "inner literals 31" {
  inspect(e("[εδ]"), content="[E(δ), E(ε)]")
}

///|
test "inner literals 32" {
  inspect(e("(?i)[εδ]"), content="[E(Δ), E(Ε), E(δ), E(ε), E(ϵ)]")
}

///|
test "inner literals 33" {
  inspect(e("a\\Ab"), content="[E(ab)]")
}

///|
test "inner literals 34" {
  inspect(e("a\\zb"), content="[E(ab)]")
}

///|
test "inner literals 35" {
  inspect(e("a(?m:^)b"), content="[E(ab)]")
}

///|
test "inner literals 36" {
  inspect(e("a(?m:$)b"), content="[E(ab)]")
}

///|
test "inner literals 37" {
  inspect(e("a\\bb"), content="[E(ab)]")
}

///|
test "inner literals 38" {
  inspect(e("a\\Bb"), content="[E(ab)]")
}

///|
test "inner literals 39" {
  inspect(e("a(?-u:\\b)b"), content="[E(ab)]")
}

///|
test "inner literals 40" {
  inspect(e("a(?-u:\\B)b"), content="[E(ab)]")
}

///|
test "inner literals 41" {
  inspect(e("^ab"), content="[E(ab)]")
}

///|
test "inner literals 42" {
  inspect(e("$ab"), content="[E(ab)]")
}

///|
test "inner literals 43" {
  inspect(e("(?m:^)ab"), content="[E(ab)]")
}

///|
test "inner literals 44" {
  inspect(e("(?m:$)ab"), content="[E(ab)]")
}

///|
test "inner literals 45" {
  inspect(e("\\bab"), content="[E(ab)]")
}

///|
test "inner literals 46" {
  inspect(e("\\Bab"), content="[E(ab)]")
}

///|
test "inner literals 47" {
  inspect(e("(?-u:\\b)ab"), content="[E(ab)]")
}

///|
test "inner literals 48" {
  inspect(e("(?-u:\\B)ab"), content="[E(ab)]")
}

///|
test "inner literals 49" {
  inspect(e("ab^"), content="[E(ab)]")
}

///|
test "inner literals 50" {
  inspect(e("ab$"), content="[E(ab)]")
}

///|
test "inner literals 51" {
  inspect(e("ab(?m:^)"), content="[E(ab)]")
}

///|
test "inner literals 52" {
  inspect(e("ab(?m:$)"), content="[E(ab)]")
}

///|
test "inner literals 53" {
  inspect(e("ab\\b"), content="[E(ab)]")
}

///|
test "inner literals 54" {
  inspect(e("ab\\B"), content="[E(ab)]")
}

///|
test "inner literals 55" {
  inspect(e("ab(?-u:\\b)"), content="[E(ab)]")
}

///|
test "inner literals 56" {
  inspect(e("ab(?-u:\\B)"), content="[E(ab)]")
}

///|
test "inner literals 57" {
  inspect(e("^aZ*b"), content="[I(aZ), E(ab)]")
}

///|
test "inner literals 58" {
  inspect(e("a?"), content="[inf]")
}

///|
test "inner literals 59" {
  inspect(e("a??"), content="[inf]")
}

///|
test "inner literals 60" {
  inspect(e("a*"), content="[inf]")
}

///|
test "inner literals 61" {
  inspect(e("a*?"), content="[inf]")
}

///|
test "inner literals 62" {
  inspect(e("a+"), content="[I(a)]")
}

///|
test "inner literals 63" {
  inspect(e("(a+)+"), content="[I(a)]")
}

///|
test "inner literals 64" {
  inspect(e("aZ{0}b"), content="[E(ab)]")
}

///|
test "inner literals 65" {
  inspect(e("aZ?b"), content="[E(aZb), E(ab)]")
}

///|
test "inner literals 66" {
  inspect(e("aZ??b"), content="[E(ab), E(aZb)]")
}

///|
test "inner literals 67" {
  inspect(e("aZ*b"), content="[I(aZ), E(ab)]")
}

///|
test "inner literals 68" {
  inspect(e("aZ*?b"), content="[E(ab), I(aZ)]")
}

///|
test "inner literals 69" {
  inspect(e("aZ+b"), content="[I(aZ)]")
}

///|
test "inner literals 70" {
  inspect(e("aZ+?b"), content="[I(aZ)]")
}

///|
test "inner literals 71" {
  inspect(e("aZ{2}b"), content="[E(aZZb)]")
}

///|
test "inner literals 72" {
  inspect(e("aZ{2,3}b"), content="[I(aZZ)]")
}

///|
test "inner literals 73" {
  inspect(e("(abc)?"), content="[inf]")
}

///|
test "inner literals 74" {
  inspect(e("(abc)??"), content="[inf]")
}

///|
test "inner literals 75" {
  inspect(e("a*b"), content="[I(a), E(b)]")
}

///|
test "inner literals 76" {
  inspect(e("a*?b"), content="[E(b), I(a)]")
}

///|
test "inner literals 77" {
  inspect(e("ab+"), content="[I(ab)]")
}

///|
test "inner literals 78" {
  inspect(e("a*b+"), content="[I(a), I(b)]")
}

///|
test "inner literals 79" {
  inspect(e("a*b*c"), content="[I(a), I(b), E(c)]")
}

///|
test "inner literals 80" {
  inspect(e("(a+)?(b+)?c"), content="[I(a), I(b), E(c)]")
}

///|
test "inner literals 81" {
  inspect(e("(a+|)(b+|)c"), content="[I(a), I(b), E(c)]")
}

///|
test "inner literals 82" {
  inspect(e("a*b*c*"), content="[inf]")
}

///|
test "inner literals 83" {
  inspect(e("a*b*c+"), content="[I(a), I(b), I(c)]")
}

///|
test "inner literals 84" {
  inspect(e("a*b+c"), content="[I(a), I(b)]")
}

///|
test "inner literals 85" {
  inspect(e("a*b+c*"), content="[I(a), I(b)]")
}

///|
test "inner literals 86" {
  inspect(e("ab*"), content="[I(ab), E(a)]")
}

///|
test "inner literals 87" {
  inspect(e("ab*c"), content="[I(ab), E(ac)]")
}

///|
test "inner literals 88" {
  inspect(e("ab+"), content="[I(ab)]")
}

///|
test "inner literals 89" {
  inspect(e("ab+c"), content="[I(ab)]")
}

///|
test "inner literals 90" {
  inspect(e("z*azb"), content="[I(z), E(azb)]")
}

///|
test "inner literals 91" {
  inspect(e("abc()xyz"), content="[E(abcxyz)]")
}

///|
test "inner literals 92" {
  inspect(e("(abc)(xyz)"), content="[E(abcxyz)]")
}

///|
test "inner literals 93" {
  inspect(e("abc()mno()xyz"), content="[E(abcmnoxyz)]")
}

///|
test "inner literals 94" {
  inspect(e("abc[a&&b]xyz"), content="[inf]")
}

///|
test "inner literals 95" {
  inspect(e("abc[a&&b]*xyz"), content="[E(abcxyz)]")
}

///|
test "inner literals 96" {
  inspect(e("abc|mno|xyz"), content="[E(abc), E(mno), E(xyz)]")
}

///|
test "inner literals 97" {
  inspect(e("abc|mZ*o|xyz"), content="[E(abc), I(mZ), E(mo), E(xyz)]")
}

///|
test "inner literals 98" {
  inspect(e("abc|M[a&&b]N|xyz"), content="[E(abc), E(xyz)]")
}

///|
test "inner literals 99" {
  inspect(e("abc|M[a&&b]*N|xyz"), content="[E(abc), E(MN), E(xyz)]")
}

///|
test "inner literals 100" {
  inspect(e("(?:|aa)aaa"), content="[E(aaa)]")
}

///|
test "inner literals 101" {
  inspect(e("(?:|aa)(?:aaa)*"), content="[inf]")
}

///|
test "inner literals 102" {
  inspect(e("(?:|aa)(?:aaa)*?"), content="[inf]")
}

///|
test "inner literals 103" {
  inspect(e("a|b*"), content="[inf]")
}

///|
test "inner literals 104" {
  inspect(e("a|b+"), content="[E(a), I(b)]")
}

///|
test "inner literals 105" {
  inspect(e("a*b|c"), content="[I(a), E(b), E(c)]")
}

///|
test "inner literals 106" {
  inspect(e("a|(?:b|c*)"), content="[inf]")
}

///|
test "inner literals 107" {
  inspect(e("(a|b)*c|(a|ab)*c"), content="[I(a), I(b), E(c)]")
}

///|
test "inner literals 108" {
  inspect(e("(ab|cd)(ef|gh)"), content="[E(abef), E(abgh), E(cdef), E(cdgh)]")
}

///|
test "inner literals 109" {
  inspect(
    e("(ab|cd)(ef|gh)(ij|kl)"),
    content="[E(abefij), E(abefkl), E(abghij), E(abghkl), E(cdefij), E(cdefkl), E(cdghij), E(cdghkl)]",
  )
}

///|
test "inner literals 110" {
  inspect(e("[a&&b]"), content="[inf]")
}

///|
test "inner literals 111" {
  inspect(e("a[a&&b]"), content="[inf]")
}

///|
test "inner literals 112" {
  inspect(e("[a&&b]b"), content="[inf]")
}

///|
test "inner literals 113" {
  inspect(e("a[a&&b]b"), content="[inf]")
}

///|
test "inner literals 114" {
  inspect(e("a|[a&&b]|b"), content="[E(a), E(b)]")
}

///|
test "inner literals 115" {
  inspect(e("a|c[a&&b]|b"), content="[E(a), E(b)]")
}

///|
test "inner literals 116" {
  inspect(e("a|[a&&b]d|b"), content="[E(a), E(b)]")
}

///|
test "inner literals 117" {
  inspect(e("a|c[a&&b]d|b"), content="[E(a), E(b)]")
}

///|
test "inner literals 118" {
  inspect(e("[a&&b]*"), content="[inf]")
}

///|
test "inner literals 119" {
  inspect(e("M[a&&b]*N"), content="[E(MN)]")
}

///|
test "inner literals 120" {
  inspect(e("."), content="[inf]")
}

///|
test "inner literals 121" {
  inspect(e("(?s)."), content="[inf]")
}

///|
test "inner literals 122" {
  inspect(e("[A-Za-z]"), content="[inf]")
}

///|
test "inner literals 123" {
  inspect(e("[A-Z]"), content="[inf]")
}

///|
test "inner literals 124" {
  inspect(e("[A-Z]{0}"), content="[inf]")
}

///|
test "inner literals 125" {
  inspect(e("[A-Z]?"), content="[inf]")
}

///|
test "inner literals 126" {
  inspect(e("[A-Z]*"), content="[inf]")
}

///|
test "inner literals 127" {
  inspect(e("[A-Z]+"), content="[inf]")
}

///|
test "inner literals 128" {
  inspect(e("1[A-Z]"), content="[I(1)]")
}

///|
test "inner literals 129" {
  inspect(e("1[A-Z]2"), content="[I(1)]")
}

///|
test "inner literals 130" {
  inspect(e("[A-Z]+123"), content="[I(123)]")
}

///|
test "inner literals 131" {
  inspect(e("[A-Z]+123[A-Z]+"), content="[I(123)]")
}

///|
test "inner literals 132" {
  inspect(e("1|[A-Z]|3"), content="[inf]")
}

///|
test "inner literals 133" {
  inspect(e("1|2[A-Z]|3"), content="[E(1), I(2), E(3)]")
}

///|
test "inner literals 134" {
  inspect(e("1|[A-Z]2[A-Z]|3"), content="[E(1), I(2), E(3)]")
}

///|
test "inner literals 135" {
  inspect(e("1|[A-Z]2|3"), content="[E(1), I(2), E(3)]")
}

///|
test "inner literals 136" {
  inspect(e("1|2[A-Z]3|4"), content="[E(1), I(2), E(4)]")
}

///|
test "inner literals 137" {
  inspect(e("(?:|1)[A-Z]2"), content="[I(2)]")
}

///|
test "inner literals 138" {
  inspect(e("a.z"), content="[I(a)]")
}

///|
test "inner literals 139" {
  inspect(e(""), content="[inf]")
}

///|
test "inner literals 140" {
  inspect(e("^"), content="[inf]")
}

///|
test "inner literals 141" {
  inspect(e("$"), content="[inf]")
}

///|
test "inner literals 142" {
  inspect(e("(?m:^)"), content="[inf]")
}

///|
test "inner literals 143" {
  inspect(e("(?m:$)"), content="[inf]")
}

///|
test "inner literals 144" {
  inspect(e("\\b"), content="[inf]")
}

///|
test "inner literals 145" {
  inspect(e("\\B"), content="[inf]")
}

///|
test "inner literals 146" {
  inspect(e("(?-u:\\b)"), content="[inf]")
}

///|
test "inner literals 147" {
  inspect(e("(?-u:\\B)"), content="[inf]")
}

///|
test "inner literals 148" {
  inspect(e("(?:){4294967295}"), content="[inf]")
}

///|
test "inner literals 149" {
  inspect(e("(?:){64}{64}{64}{64}{64}{64}"), content="[inf]")
}

///|
test "inner literals 150" {
  inspect(e("x{0}{4294967295}"), content="[inf]")
}

///|
test "inner literals 151" {
  inspect(e("(?:|){4294967295}"), content="[inf]")
}

///|
test "inner literals 152" {
  inspect(e("(?:){8}{8}{8}{8}{8}{8}{8}{8}{8}{8}{8}{8}{8}{8}"), content="[inf]")
}

///|
test "inner literals 153" {
  let repa = "a".repeat(100)
  inspect(
    e("a{8}{8}{8}{8}{8}{8}{8}{8}{8}{8}{8}{8}{8}{8}"),
    content="[I(\{repa})]",
  )
}

///|
test "inner literals 154" {
  inspect(e("Z"), content="[E(Z)]")
}

///|
test "inner literals 155" {
  inspect(
    e("foobarfoobar|foobar|foobarzfoobar|foobarfoobar"),
    content="[I(foobar)]",
  )
}

///|
test "inner literals 156" {
  inspect(e("abba|akka|abccba"), content="[E(abba), E(akka), E(abccba)]")
}

///|
test "inner literals 157" {
  inspect(e("sam|samwise"), content="[E(sam)]")
}

///|
test "inner literals 158" {
  inspect(e("foobarfoo|foo||foozfoo|foofoo"), content="[inf]")
}

///|
test "inner literals 159" {
  inspect(e("foobarfoo|foo| |foofoo"), content="[inf]")
}

///|
test "inner literals 160" {
  inspect(e("(?i:e.x|ex)"), content="[I(X), I(x)]")
}

///|
test "inner literals 161" {
  let letters = "ͱͳͷΐάέήίΰαβγδεζηθικλμνξοπρςστυφχψωϊϋ"
  inspect(e(letters), content="[E(\{letters})]")
  let repa = "a".repeat(100)
  inspect(
    e("a{8}{8}{8}{8}{8}{8}{8}{8}{8}{8}{8}{8}{8}{8}"),
    content="[I(\{repa})]",
  )
}
