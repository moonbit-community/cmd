///|
test "exact prefilter line counts handle variant sets offset windows and unterminated tails" {
  let lines = [b"", b"alpha beta", b"xxx", b"aaa", b"no match", b""]
  for
    literals in [
      [b"a"],
      [b"x", b"y"],
      [b"a", b"b", b"c"],
      [b"a", b"b", b"c", b"d"],
      [b"alpha"],
      [b"alpha", b"beta", b"gamma"],
      [b"aa", b"ab", b"ac", b"ad", b"ae", b"af", b"ag", b"ah"],
    ] {
    let pre = @automata.Prefilter::new(literals).unwrap()
    let mut expected = 0L
    let mut body = b""
    for line in lines {
      if literals.iter().any(literal => line.find(literal) is Some(_)) {
        expected += 1
      }
      body = body + line + b"\n"
    }
    body = body + b"beta"
    if literals.iter().any(literal => b"beta".find(literal) is Some(_)) {
      expected += 1
    }
    let hay = (b"prefix" + body + b"suffix").to_fixedarray()
    assert_eq(pre.count_lines(hay, 6, 6 + body.length(), b'\n'), expected)
    assert_eq(pre.count_lines(hay, 6, 6, b'\n'), 0)
  }
}
