///|
test "test exposes portable file predicates" {
  assert_true(is_unary("-L"))
  assert_true(is_unary("-s"))
  assert_true(is_binary("-nt"))
  assert_true(is_binary("-ot"))
  assert_true(is_binary("-ef"))
}

///|
async test "identity follows standalone test argument precedence" {
  let single : Parser = { args: ["-ef"], pos: 0, }
  assert_true(single.evaluate_count(1))
  guard !(@async.platform is Windows) else { return }
  let group : Parser = { args: ["(", ".", "-ef", "./.", ")"], pos: 0, }
  assert_true(group.evaluate_count(5))
  assert_false(eval_binary("", "-ef", ""))
}
