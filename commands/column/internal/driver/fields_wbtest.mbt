///|
async test "field metadata thresholds preserve widths at exact row and byte limits" {
  for length in [1535, 1536, 1537] {
    ignore(
      with_snapshot(table=true, separator=Some(":"), snapshot => {
        let pending = SpoolBatch::new()
        let line = "x".repeat(length - 30) + ":x".repeat(15)
        assert_true(snapshot.stage_record(pending, line))
        assert_eq(snapshot.field_plans.contains(0L), length >= 1536)
        assert_eq(
          snapshot.widths,
          Array::makei(16, i => if i == 0 { length - 30 } else { 1 }),
        )
        if snapshot.field_plans.get(0L) is Some(plan) {
          let data = @utf8.encode(line)
          let cached = observed_plan(data, plan)
          let ordinary = line
            .split(":")
            .map(field => {
              data: @utf8.encode(field.to_owned())[:],
              width: @layout.display_width(field.to_owned(), table=true),
            })
            .collect()
          for i in 0..<ordinary.length() {
            assert_eq(cached[i].data, ordinary[i].data)
            assert_eq(cached[i].width, ordinary[i].width)
          }
        }
        false
      }),
    )
  }
  for
    length in [
      FIELD_PLAN_MIN_ROW_BYTES - 1,
      FIELD_PLAN_MIN_ROW_BYTES,
      FIELD_PLAN_MIN_ROW_BYTES + 1,
    ] {
    ignore(
      with_snapshot(table=true, separator=Some(":"), snapshot => {
        let pending = SpoolBatch::new()
        assert_true(snapshot.stage_record(pending, "x".repeat(length)))
        assert_eq(
          snapshot.field_plans.contains(0L),
          length >= FIELD_PLAN_MIN_ROW_BYTES,
        )
        assert_eq(snapshot.widths, [length])
        false
      }),
    )
  }
  for available in [23, 24, 25] {
    ignore(
      with_snapshot(table=true, separator=Some(":"), snapshot => {
        let before = FIELD_PLAN_BYTE_LIMIT - available
        snapshot.field_plan_bytes = before
        let pending = SpoolBatch::new()
        assert_true(snapshot.stage_record(pending, "x".repeat(1024) + ":y"))
        assert_eq(
          snapshot.field_plan_bytes - before,
          if available < 24 {
            0
          } else {
            24
          },
        )
        assert_eq(snapshot.widths, [1024, 1])
        false
      }),
    )
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
    let cached = observed_plan(@utf8.encode(large)[:], snapshot.field_plans[0])
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
