///|
test "perl classes" {
  inspect(@unicode.is_word_character('a'.to_int()), content="true")
  inspect(@unicode.is_word_character('δ'.to_int()), content="true")
  inspect(@unicode.is_word_character(' '.to_int()), content="false")
  debug_inspect(@unicode.perl_digit()[0], content="(48, 57)")
  debug_inspect(@unicode.perl_space()[0], content="(9, 13)")
}

///|
test "case folding" {
  debug_inspect(@unicode.simple_fold('k'.to_int()), content="[75, 8490]")
  debug_inspect(@unicode.simple_fold('A'.to_int()), content="[97]")
  debug_inspect(@unicode.simple_fold('☃'.to_int()), content="[]")
  inspect(@unicode.fold_overlaps('@'.to_int(), 'A'.to_int()), content="true")
  inspect(@unicode.fold_overlaps('['.to_int(), '`'.to_int()), content="false")
}

///|
test "class lookups" {
  let greek = @unicode.class(Binary("Greek"))
  debug_inspect(greek[0], content="(880, 883)")
  let l = @unicode.class(OneLetter('L'))
  debug_inspect(l[0], content="(65, 90)")
  let sc = @unicode.class(ByValue("sc", "greek"))
  debug_inspect(sc[0], content="(880, 883)")
  let any = @unicode.class(Binary("Any"))
  debug_inspect(any, content="[(0, 55295), (57344, 1114111)]")
  let alpha = @unicode.class(Binary("Alphabetic"))
  debug_inspect(alpha[0], content="(65, 90)")
  let age = @unicode.class(ByValue("age", "1.1"))
  debug_inspect(age[0], content="(0, 501)")
  inspect(
    try @unicode.class(Binary("nope")) catch {
      e => "\{Repr(e)}"
    } noraise {
      _ => "ok"
    },
    content="PropertyNotFound",
  )
  debug_inspect(@unicode.class(Binary("Assigned"))[0], content="(0, 887)")
}
