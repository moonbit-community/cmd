///|
async test "precision preparation records rejected pairs before admitting actual metadata" {
  // Injection checks preparation control flow only; real CLI scenarios use
  // filesystem writes/readback and never obtain timestamps from this sequence.
  let pairs = [
    ((1L, 999999999), (2L, 1)),
    ((2L, 1), (2L, 1)),
    ((2L, -1), (2L, 1)),
    ((2L, 1), (2L, 1000000000)),
    ((2L, 1), (2L, 2)),
  ]
  let calls = Ref(0)
  let events : Array[Json] = []
  let result = prepare_subsecond_fixture(
    () => {
      let pair = pairs[calls.val]
      calls.val += 1
      pair
    },
    event => events.push(event),
  )
  assert_eq(result, pairs[4])
  assert_eq(calls.val, 5)
  assert_eq(events.length(), 5)
  for i, event in events {
    guard event
      is {
        "phase": String("subsecond-fixture-attempt"),
        "attempt": Number(attempt, ..),
        "early_mtime": early,
        "late_mtime": late,
        "formed": formed,
        ..
      } else {
      fail("preparation observation missing")
    }
    assert_eq(attempt, (i + 1).to_double())
    assert_eq(early, Json(pairs[i].0))
    assert_eq(late, Json(pairs[i].1))
    assert_eq(formed, Json(i == 4))
  }
}

///|
async test "precision preparation exhausts eight invalid pairs without a ninth attempt" {
  let calls = Ref(0)
  let events : Array[Json] = []
  try
    prepare_subsecond_fixture(
      () => {
        calls.val += 1
        ((1L, 999999999), (2L, 1))
      },
      event => events.push(event),
    )
  catch {
    error =>
      assert_true(
        error.to_string().contains("no valid pair after 8 preparations"),
      )
  } noraise {
    _ => fail("unformed fixture must not pass")
  }
  assert_eq(calls.val, 8)
  assert_eq(events.length(), 8)
  assert_true(events.all(event => event is { "formed": False, .. }))
}

///|
async test "precision preparation preserves the original attempt failure" {
  let calls = Ref(0)
  let records = Ref(0)
  let original = Failure("injected fixture write failure")
  try
    prepare_subsecond_fixture(
      () => {
        calls.val += 1
        raise original
      },
      _ => records.val += 1,
    )
  catch {
    error => assert_eq(error.to_string(), original.to_string())
  } noraise {
    _ => fail("failed fixture IO must not pass")
  }
  assert_eq(calls.val, 1)
  assert_eq(records.val, 0)
}

///|
async test "precision preparation cannot accept an unrecorded valid pair" {
  let calls = Ref(0)
  let records = Ref(0)
  let original = Failure("injected fixture recording failure")
  try
    prepare_subsecond_fixture(
      () => {
        calls.val += 1
        ((1L, 1), (1L, 2))
      },
      _ => {
        records.val += 1
        raise original
      },
    )
  catch {
    error => assert_eq(error.to_string(), original.to_string())
  } noraise {
    _ => fail("failed observation persistence must not pass")
  }
  assert_eq(calls.val, 1)
  assert_eq(records.val, 1)
}

///|
async test "precision preparation deadline includes attempt and observation persistence" {
  for pending in ["prepare", "record"] {
    let calls = Ref(0)
    let unwound = Ref(false)
    let records = Ref(0)
    try
      prepare_subsecond_fixture(
        () => {
          calls.val += 1
          if pending == "prepare" {
            defer {
              unwound.val = true
            }
            @async.sleep(10000)
          }
          ((1L, 1), (1L, 2))
        },
        _ => {
          records.val += 1
          if pending == "record" {
            defer {
              unwound.val = true
            }
            @async.sleep(10000)
          }
        },
        timeout_ms=10,
      )
    catch {
      error =>
        assert_true(error.to_string().contains("preparation deadline expired"))
    } noraise {
      _ => fail("timed-out preparation must not pass")
    }
    assert_eq(calls.val, 1)
    assert_true(unwound.val)
    assert_eq(records.val, if pending == "prepare" { 0 } else { 1 })
  }
}

///|
async test "precision preparation propagates cancellation from its caller" {
  let calls = Ref(0)
  let unwound = Ref(false)
  let records = Ref(0)
  let result = @async.with_timeout_opt(10, () => {
    prepare_subsecond_fixture(
      () => {
        calls.val += 1
        defer {
          unwound.val = true
        }
        @async.sleep(10000)
        ((1L, 1), (1L, 2))
      },
      _ => records.val += 1,
    )
  })
  assert_eq(result, None)
  assert_eq(calls.val, 1)
  assert_true(unwound.val)
  assert_eq(records.val, 0)
}
