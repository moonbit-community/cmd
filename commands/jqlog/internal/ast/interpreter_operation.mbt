///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Evaluate binary operation expressions
fn eval_operation_expr(
  left : Expr,
  op : BinaryOp,
  right : Expr,
  input : Json,
  env : Env,
) -> Iter[Json] raise InterpreterError {
  let left_results = eval_with_env(left, input, env).collect()
  let right_results = eval_with_env(right, input, env).collect()
  let all_results : Array[Json] = left_results.fold(init=[], fn(
    acc,
    left_val,
  ) raise InterpreterError {
    right_results.each(fn(right_val) raise InterpreterError {
      acc.push(eval_binary_op(op, left_val, right_val))
    })
    acc
  })
  all_results.iter()
}
