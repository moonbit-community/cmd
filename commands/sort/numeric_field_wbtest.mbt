///|
test "sort fractional field cache preserves exact decimal ordering and raw marker collisions" {
  let ordered = [
    b"-9007199254740993", b"-9007199254740992", b"-1.000000000000000002", b"-1.000000000000000001",
    b"-.00000000000000000001", b"0", b".00000000000000000001", b"1.000000000000000001",
    b"1.000000000000000002", b"9007199254740992", b"9007199254740993",
  ]
  for i, left in ordered {
    for j, right in ordered {
      let expected = i.compare(j)
      assert_eq(numeric_compare(left, right).compare(0), expected)
      assert_eq(
        numeric_field_value(prepare_numeric_field(left))
        .compare(numeric_field_value(prepare_numeric_field(right)))
        .compare(0),
        expected,
      )
    }
  }
  for
    zero in [
      b"", b"-0.000", b"+9.1", b"-", b"\xff12345678", b"\xff\x00\x00\x00\x00\x00\x00\xf0\x7f",
    ] {
    assert_eq(numeric_compare(zero, b"0"), 0)
    assert_eq(prepare_numeric_field(zero), prepare_numeric_field(b"0"))
  }
  for
    (left, right) in [
      (b"  -0012.34000tail", b"-12.34"),
      (b".5", b"00.500"),
      (b"1e3", b"1"),
      (b"2.", b"2"),
    ] {
    assert_eq(numeric_compare(left, right), 0)
    assert_eq(prepare_numeric_field(left), prepare_numeric_field(right))
  }
  let large = @utf8.encode("9".repeat(4096))
  let larger = @utf8.encode("1" + "0".repeat(4096))
  assert_true(numeric_compare(large, larger) < 0)
}

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
  let specs = [parse_key("1,1n", test_modifiers())]
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
