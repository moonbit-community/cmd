///|
async test "cohort direct child wait errors cannot report cancellation success" {
  for label in ["tail follow", "sleep cancellation"] {
    let calls = Ref(0)
    try
      wait_for_direct_child(label, () => {
        calls.val += 1
        fail("injected direct child wait failure")
      })
    catch {
      error => {
        assert_true(error.to_string().contains("cleanup infrastructure"))
        assert_true(error.to_string().contains(label))
      }
    } noraise {
      _ => fail("a failed direct child wait must not pass cancellation")
    }
    assert_eq(calls.val, 1)
  }
  wait_for_direct_child("completed child", () => 0)
}
