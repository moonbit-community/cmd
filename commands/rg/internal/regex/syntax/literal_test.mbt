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
fn prefixes(pattern : String) -> String {
  let hir = @syntax.parse(pattern) catch { e => abort(e.to_string()) }
  show_seq(@syntax.Extractor::new().extract(hir))
}

///|
test "literal extraction" {
  inspect(prefixes("a"), content="[E(a)]")
  inspect(prefixes("ab|cd"), content="[E(ab), E(cd)]")
  inspect(prefixes("a*"), content="[I(a), E()]")
  inspect(prefixes("a*?"), content="[E(), I(a)]")
  inspect(prefixes("[ab]c"), content="[E(ac), E(bc)]")
  inspect(prefixes("a+"), content="[I(a)]")
  inspect(prefixes("abc\\w"), content="[I(abc)]")
  inspect(prefixes("\\w"), content="[inf]")
  inspect(prefixes("(?i)ab"), content="[E(AB), E(Ab), E(aB), E(ab)]")
  inspect(prefixes("a{3}"), content="[E(aaa)]")
  inspect(prefixes("^foo"), content="[E(foo)]")
}

///|
test "optimize prefix" {
  let hir = @syntax.parse("foobar|foobaz") catch { _ => abort("") }
  let seq = @syntax.Extractor::new().extract(hir)
  seq.optimize_for_prefix_by_preference()
  inspect(
    show_seq(seq),
    content=(
      #|[I(fooba)]
    ),
  )
  let hir = @syntax.parse("samwise|sam") catch { _ => abort("") }
  let seq = @syntax.Extractor::new().extract(hir)
  seq.optimize_for_prefix_by_preference()
  inspect(show_seq(seq), content="[E(samwise), E(sam)]")
}
