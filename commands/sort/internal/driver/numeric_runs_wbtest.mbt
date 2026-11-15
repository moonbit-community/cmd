///|
async test "exact numeric keys survive disk runs stable ties unique and merge" {
  let root = @fs.tmpdir(prefix="sort-exact-runs-")
  defer @fs.rmdir(root, recursive=true)
  let input = root + "/input"
  @fs.write_file(
    input, "9007199254740993 A\n9007199254740992 B\n09007199254740992 C\n1.000000000000000002 D\n1.000000000000000001 E\n",
  )
  let numeric = test_modifiers()
  numeric.mode = Numeric
  let specs = [@order.parse_key("1,1n", test_modifiers())]
  for budget in [0L, 67108864L] {
    assert_eq(
      run_sort_fixture([input], numeric, specs~, budget~, stable=true, fan_in=2),
      b"1.000000000000000001 E\n1.000000000000000002 D\n9007199254740992 B\n09007199254740992 C\n9007199254740993 A\n",
    )
    assert_eq(
      run_sort_fixture([input], numeric, specs~, budget~, unique=true, fan_in=2),
      b"1.000000000000000001 E\n1.000000000000000002 D\n9007199254740992 B\n9007199254740993 A\n",
    )
  }
  let left = root + "/left"
  let right = root + "/right"
  @fs.write_file(
    left, "-9007199254740993\n1.000000000000000001\n9007199254740993\n",
  )
  @fs.write_file(
    right, "-9007199254740992\n1.000000000000000002\n9007199254740992\n",
  )
  assert_eq(
    run_sort_fixture(
      [left, right],
      numeric,
      specs~,
      merge=true,
      unique=true,
      budget=0,
      fan_in=2,
    ),
    b"-9007199254740993\n-9007199254740992\n1.000000000000000001\n1.000000000000000002\n9007199254740992\n9007199254740993\n",
  )
  assert_eq(@fs.readdir(root).length(), 3)
}
