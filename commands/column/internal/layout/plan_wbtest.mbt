///|
test "field plans preserve decoded data and widths across cached row thresholds" {
  let separator = Separator::new(Some(":"))
  for length in [1535, 1536, 1537] {
    let line = "x".repeat(length - 30) + ":x".repeat(15)
    let data = @utf8.encode(line)
    let plan = separator.observe_fields(data, [], Some(data.length() / 8))
    assert_eq(plan is Some(_), length >= 1536)
    if plan is Some(plan) {
      let cached = fields_from_plan(data, plan)
      let ordinary = separator.table_fields(data)
      for i in 0..<ordinary.length() {
        assert_eq(cached[i].data, ordinary[i].data)
        assert_eq(cached[i].width, ordinary[i].width)
      }
    }
  }
  let large = @utf8.encode("x".repeat(1030) + ":\u001b[31my\u001b[0m")
  let plan = separator
    .observe_fields(large, [], Some(large.length() / 8))
    .unwrap()
  let cached = fields_from_plan(large, plan)
  assert_eq(cached.length(), 2)
  assert_eq(cached[0].width, 1030)
  assert_eq(cached[1].width, 1)
  assert_eq(@utf8.decode(cached[1].data), "\u001b[31my\u001b[0m")
}
