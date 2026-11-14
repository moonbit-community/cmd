///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Literal values in jq expressions
#derive(Eq, ToJson, Debug)
pub(all) enum Literal {
  Null
  Bool(Bool)
  Number(Double)
  String(String)
}

///|
/// Preserve method-style access to derived equality operations.
pub extend Literal with Eq::{not_equal, equal}

///|
/// Preserve method-style access to derived JSON conversion.
pub extend Literal with ToJson::{to_json}

///|
/// Preserve method-style access to derived debug representation.
pub extend Literal with @debug.Debug::{to_repr}

///|
fn Literal::to_runtime_json(self : Literal) -> Json {
  match self {
    Null => null
    Bool(b) => Json::boolean(b)
    Number(n) => Json::number(n)
    String(s) => Json::string(s)
  }
}

///|
pub impl Show for Literal with fn output(self, logger) {
  logger.write_string(@debug.render(self.to_repr(), max_depth=2147483647))
}

///|
/// Preserve method-style access to display operations.
pub extend Literal with Show::{to_string, output}
