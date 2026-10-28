///|
priv struct Lossy {
  f : (Int64, String) -> Bool raise
}

///|
fn Lossy::new(f : (Int64, String) -> Bool raise) -> Lossy {
  { f, }
}

///|
impl @searcher.Sink for Lossy with fn matched(self, _searcher, mat) {
  guard mat.line_number is Some(n) else { fail("line numbers not enabled") }
  (self.f)(
    n,
    @utf8.decode_lossy(
      Bytes::from_array(
        mat.buf[mat.buf_start + mat.start:mat.buf_start + mat.end],
      ),
    ),
  )
}

///|
async test "regression_2260" {
  let matcher = SearchMatcher::new(
    ["^\\w+$"],
    line_terminator=Some(b'\n').map(@matcher.LineTerminator::byte),
  )
  let searcher = @searcher.SearcherBuilder::new().line_number(true).build()
  let mut matched = false
  searcher.search_bytes(
    matcher,
    b"GATC\n",
    Lossy::new((_, _) => {
      matched = true
      true
    }),
  )
  assert_true(matched)
}
