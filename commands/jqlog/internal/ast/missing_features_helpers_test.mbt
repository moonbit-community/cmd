///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Test helper to check if features are missing
fn test_feature(query : String, input : String) -> String {
  let expr = @parser.parse(query) catch { e => return "ParseError: \{e}" }
  let json = @json.parse(input) catch { e => return "JsonError: \{e}" }
  let results = @ast.eval(expr, json).collect() catch {
    e => return "EvalError: \{e}"
  }
  results.map(@debug.to_string).join("\n")
}
