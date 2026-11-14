///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Binary operators in jq
#derive(Eq, ToJson, Debug)
pub(all) enum BinaryOp {
  Add // +
  Subtract // -
  Multiply // *
  Divide // /
  Modulo // %
  Equal // ==
  NotEqual // !=
  LessThan // <
  LessEq // <=
  GreaterThan // >
  GreaterEq // >=
  And // and
  Or // or
}

///|
/// Preserve method-style access to derived equality operations.
pub extend BinaryOp with Eq::{not_equal, equal}

///|
/// Preserve method-style access to derived JSON conversion.
pub extend BinaryOp with ToJson::{to_json}

///|
/// Preserve method-style access to derived debug representation.
pub extend BinaryOp with @debug.Debug::{to_repr}

///|
pub impl Show for BinaryOp with fn output(self, logger) {
  logger.write_string(@debug.render(self.to_repr(), max_depth=2147483647))
}

///|
/// Preserve method-style access to display operations.
pub extend BinaryOp with Show::{to_string, output}
