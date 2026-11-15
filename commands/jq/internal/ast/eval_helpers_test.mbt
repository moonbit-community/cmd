///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Helper for coverage tests
fn coverage_eval(query : String, input : String) -> Array[Json] raise {
  let expr = @parser.parse(query)
  let json_input = @json.parse(input)
  @ast.eval(expr, json_input).collect()
}

///|
fn assert_coverage_eval_error(query : String, input : String) -> Unit raise {
  try coverage_eval(query, input) catch {
    _ => ()
  } noraise {
    _ => fail("expected jq evaluation error")
  }
}
