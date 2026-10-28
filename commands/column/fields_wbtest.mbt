///|
test "byte fields preserve empty delimiters and control-sequence widths" {
  for separator in [None, Some(""), Some(":"), Some(" \t,:")] {
    let split = FieldSeparator::new(separator)
    for
      line in [
        "", "::", "a:b,,c", "\u001b[31mred\u001b[0m:next", "x\t[broken:z", "\u0000[1m:a",
      ] {
      let data = @utf8.encode(line)
      let reference = split_fields_reference(line, separator)
      let fields = split.table_fields(data[:])
      assert_eq(fields.length(), reference.length())
      for i, field in fields {
        assert_eq(@utf8.decode(field.data), reference[i])
        assert_eq(field.width, display_width(reference[i], table=true))
      }
    }
  }
}

///|
async test "large-row field metadata is bounded and does not alter snapshot storage" {
  let _ = with_snapshot(table=true, separator=Some(":"), snapshot => {
    let pending = SpoolBatch::new()
    let large = "x".repeat(1030) + ":\u001b[31my\u001b[0m"
    for _ in 0..<140 {
      if !snapshot.stage_record(pending, large) {
        pending.flush(snapshot.data_writer, snapshot.index_writer)
      }
      assert_true(snapshot.field_plans.length() <= 128)
      assert_true(snapshot.field_plan_bytes <= 65536)
    }
    assert_eq(snapshot.field_plans.length(), 128)
    assert_eq(snapshot.field_plan_bytes, 128 * 24)
    let cached = fields_from_plan(
      @utf8.encode(large)[:],
      snapshot.field_plans[0],
    )
    assert_eq(cached.length(), 2)
    assert_eq(cached[0].width, 1030)
    assert_eq(cached[1].width, 1)
    assert_eq(@utf8.decode(cached[1].data), "\u001b[31my\u001b[0m")
    let dense = "a:".repeat(1024)
    if !snapshot.stage_record(pending, dense) {
      pending.flush(snapshot.data_writer, snapshot.index_writer)
    }
    pending.flush(snapshot.data_writer, snapshot.index_writer)
    snapshot.finish()
    assert_eq(
      snapshot.size,
      (140 * @utf8.encode(large).length() + dense.length()).to_int64(),
    )
    assert_eq(snapshot.line(0), large)
    assert_eq(snapshot.line(140), dense)
    false
  })
  let _ = with_snapshot(table=true, separator=Some(":"), snapshot => {
    let pending = SpoolBatch::new()
    ignore(snapshot.stage_record(pending, "a:".repeat(1024)))
    assert_eq(snapshot.field_plans.length(), 0)
    assert_eq(snapshot.field_plan_bytes, 0)
    assert_eq(snapshot.widths.length(), 1025)
    assert_eq(snapshot.widths[0], 1)
    assert_eq(snapshot.widths[1024], 0)
    false
  })
}
