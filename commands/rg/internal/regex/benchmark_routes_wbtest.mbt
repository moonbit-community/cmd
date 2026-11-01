///|
// These controls correspond to explore's 1024-byte route records. Required
// literals remain present in all three regimes, including full-match misses.
fn benchmark_route_record(hit : Bool) -> Bytes {
  let prefix = if hit { b"0001 alpha " } else { b"Q alpha 0001 " }
  Bytes::makei(1024, column => {
    if column == 1023 {
      b'\n'
    } else if column < prefix.length() {
      prefix[column]
    } else if hit && column == 1022 {
      b'Q'
    } else {
      (97 + column * 13 % 26).to_byte()
    }
  })
}

///|
test "benchmark regex controls prepare the Boolean engine for hits and false candidates" {
  for
    (kind, expected) in [
      ("hit", 1024L),
      ("candidate-miss", 0L),
      ("mixed", 256L),
    ] {
    let re = Regex::new("[0-9]{4}.*Q|ZZ")
    let required = Regex::new("Q|ZZ")
    let data = Bytes::makei(1024 * 1024, offset => {
      let record = offset / 1024
      let hit = kind == "hit" || (kind == "mixed" && record % 4 == 0)
      let column = offset % 1024
      let prefix = if hit { b"0001 alpha " } else { b"Q alpha 0001 " }
      if column == 1023 {
        b'\n'
      } else if column < prefix.length() {
        prefix[column]
      } else if hit && column == 1022 {
        b'Q'
      } else {
        (97 + (record * 17 + column * 13) % 26).to_byte()
      }
    }).to_fixedarray()
    assert_true(
      required.search_half(data, 0, data.length(), 0, data.length()) is Some(_),
    )
    assert_true(re.count_plan is Uninitialized)
    assert_eq(
      re.count_boolean_lines(
        data,
        0,
        data.length(),
        b'\n',
        required=Some(required),
      ),
      Some(expected),
    )
    assert_true(re.count_plan is Ready(_))
    assert_eq(
      re.find(benchmark_route_record(kind == "hit")) is Some(_),
      kind == "hit",
    )
  }
}
