///|
async test "find batches use UTF-8 budgets and execute completed batches during traversal" {
  let batch = FindBatch::new(["cmd", "{}", "{}"], limit=16L)
  let invocations : Array[Array[String]] = []
  let execute : async (Array[String]) -> Bool = argv => {
    invocations.push(argv)
    true
  }
  assert_true(batch.push("\u00e9", execute~))
  assert_true(batch.push("x", execute~))
  assert_true(invocations.is_empty())
  assert_true(batch.push("last", execute~))
  assert_eq(invocations, [["cmd", "\u00e9", "x", "\u00e9", "x"]])
  assert_eq(batch.values, ["last"])
  assert_eq(batch.bytes, 14L)
  assert_true(batch.flush(execute~))
  assert_eq(invocations[1], ["cmd", "last", "last"])
  assert_true(batch.flush(execute~))
  assert_eq(invocations.length(), 2)
}

///|
async test "find failed batches are consumed and later values remain executable" {
  let batch = FindBatch::new(["cmd", "{}"], limit=8L)
  assert_true(batch.push("one"))
  assert_false(batch.push("two", execute=_ => false))
  assert_eq(batch.values, ["two"])
  assert_true(
    batch.flush(execute=argv => {
      assert_eq(argv, ["cmd", "two"])
      true
    }),
  )
  assert_true(batch.values.is_empty())
}
