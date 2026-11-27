///|
test "disjoint affinity ranges count their inclusive endpoints" {
  assert_eq(cpu_count("0,3-4,10-12"), 6UL)
  try cpu_count("2-1") catch {
    _ => ()
  } noraise {
    _ => fail("accepted descending range")
  }
}
