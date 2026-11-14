///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Integration helper to parse and eval
fn jq(query : String, input : String) -> Array[Json] raise {
  let expr = @parser.parse(query)
  let json = @json.parse(input)
  @ast.eval(expr, json).collect()
}

///|
fn assert_jq_error(query : String, input : String) -> Unit raise {
  try jq(query, input) catch {
    _ => ()
  } noraise {
    _ => fail("expected jq evaluation error")
  }
}
