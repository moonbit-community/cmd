///|
test "ordered ordinary threads agree with explicit tagged DFS" {
  let inputs = [
    "", "a", "b", "aa", "ab", "ba", "bb", "aaa", "aab", "aba", "abb", "baa", "bab",
    "bba", "bbb", "aaaa", "abab",
  ]
  for
    source in [
      "a*", "a|aa", "(a|aa)(a*)", "(a*)*", "((a*)*)*", "(a|(b))*", "(a?)*", "(a?)(a*)",
      "(a|())*", "((a|b)*)", "(a|ab){0,2}", "(a*){2,}", "((a?)*)b?", "(a|b)*a(a|b)*",
    ] {
    let pattern = compile(source, extended=true)
    for input in inputs {
      let ordinary = pattern.ordinary(input, 0, false, false, true)
      let spans = pattern.ordinary(input, 0, false, false, false)
      assert_eq(
        spans.map(hit => (hit.start, hit.end)),
        ordinary.map(hit => (hit.start, hit.end)),
        msg=source + " spans on " + input,
      )
      let mut explicit : Spans? = None
      for start in 0..<=input.length() {
        if pattern.at(input, start, false, false) is Some(hit) {
          explicit = Some(hit)
          break
        }
      }
      assert_eq(
        ordinary.map(hit => (hit.start, hit.end, hit.captures)),
        explicit.map(hit => (hit.start, hit.end, hit.captures)),
        msg=source + " on " + input,
      )
    }
  }
}
