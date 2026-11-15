///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Token types for jq lexer
#derive(Eq)
pub(all) enum Token {
  // Literals
  TNumber(Double)
  TString(String)
  TStringInterpolation(Array[(String, String?)]) // parts with optional expressions
  TTrue
  TFalse
  TNull
  TIdentifier(String)
  TVariable(String) // $name
  TFormat(String) // @base64, @uri, etc.
  // Operators
  TDot // .
  TDotDot // ..
  TPipe // |
  TComma // ,
  TColon // :
  TSemicolon // ;
  TQuestion // ?
  // Brackets
  TLeftParen // (
  TRightParen // )
  TLeftBracket // [
  TRightBracket // ]
  TLeftBrace // {
  TRightBrace // }
  // Arithmetic
  TPlus // +
  TMinus // -
  TStar // *
  TSlash // /
  TPercent // %
  // Comparison
  TEq // ==
  TNeq // !=
  TLt // <
  TLe // <=
  TGt // >
  TGe // >=
  // Assignment
  TAssign // =
  TUpdate // |=
  TAlternative // //
  TAddAssign // +=
  TSubAssign // -=
  TMulAssign // *=
  TDivAssign // /=
  TModAssign // %=
  TAltAssign // //=
  // Keywords
  TAnd // and
  TOr // or
  TNot // not
  TIf // if
  TThen // then
  TElse // else
  TElif // elif
  TEnd // end
  TAs // as
  TReduce // reduce
  TForeach // foreach
  TTry // try
  TCatch // catch
  TDef // def
  TEof
}

///|
/// Preserve method-style access to derived equality operations.
pub extend Token with Eq::{not_equal, equal}

///|
/// Preserve method-style access to derived debug representation.
pub extend Token with @debug.Debug::{to_repr}

///|
pub impl Show for Token with fn output(self, logger) {
  logger.write_string(@debug.render(self.to_repr(), max_depth=2147483647))
}

///|
/// Preserve method-style access to display operations.
pub extend Token with Show::{to_string, output}

///|
// Token labels are part of existing parser diagnostics and frozen lexer records.
pub impl @debug.Debug for Token with fn to_repr(self) {
  match self {
    TNumber(value) =>
      @debug.Repr::ctor("TNumber", [(None, @debug.Debug::to_repr(value))])
    TString(value) =>
      @debug.Repr::ctor("TString", [(None, @debug.Debug::to_repr(value))])
    TStringInterpolation(value) =>
      @debug.Repr::ctor("TStringInterpolation", [
        (None, @debug.Debug::to_repr(value)),
      ])
    TTrue => @debug.Repr::ctor("TTrue", [])
    TFalse => @debug.Repr::ctor("TFalse", [])
    TNull => @debug.Repr::ctor("TNull", [])
    TIdentifier(value) =>
      @debug.Repr::ctor("TIdentifier", [(None, @debug.Debug::to_repr(value))])
    TVariable(value) =>
      @debug.Repr::ctor("TVariable", [(None, @debug.Debug::to_repr(value))])
    TFormat(value) =>
      @debug.Repr::ctor("TFormat", [(None, @debug.Debug::to_repr(value))])
    TDot => @debug.Repr::ctor("TDot", [])
    TDotDot => @debug.Repr::ctor("TDotDot", [])
    TPipe => @debug.Repr::ctor("TPipe", [])
    TComma => @debug.Repr::ctor("TComma", [])
    TColon => @debug.Repr::ctor("TColon", [])
    TSemicolon => @debug.Repr::ctor("TSemicolon", [])
    TQuestion => @debug.Repr::ctor("TQuestion", [])
    TLeftParen => @debug.Repr::ctor("TLParen", [])
    TRightParen => @debug.Repr::ctor("TRParen", [])
    TLeftBracket => @debug.Repr::ctor("TLBracket", [])
    TRightBracket => @debug.Repr::ctor("TRBracket", [])
    TLeftBrace => @debug.Repr::ctor("TLBrace", [])
    TRightBrace => @debug.Repr::ctor("TRBrace", [])
    TPlus => @debug.Repr::ctor("TPlus", [])
    TMinus => @debug.Repr::ctor("TMinus", [])
    TStar => @debug.Repr::ctor("TStar", [])
    TSlash => @debug.Repr::ctor("TSlash", [])
    TPercent => @debug.Repr::ctor("TPercent", [])
    TEq => @debug.Repr::ctor("TEq", [])
    TNeq => @debug.Repr::ctor("TNeq", [])
    TLt => @debug.Repr::ctor("TLt", [])
    TLe => @debug.Repr::ctor("TLe", [])
    TGt => @debug.Repr::ctor("TGt", [])
    TGe => @debug.Repr::ctor("TGe", [])
    TAssign => @debug.Repr::ctor("TAssign", [])
    TUpdate => @debug.Repr::ctor("TUpdate", [])
    TAlternative => @debug.Repr::ctor("TAlternative", [])
    TAddAssign => @debug.Repr::ctor("TAddAssign", [])
    TSubAssign => @debug.Repr::ctor("TSubAssign", [])
    TMulAssign => @debug.Repr::ctor("TMulAssign", [])
    TDivAssign => @debug.Repr::ctor("TDivAssign", [])
    TModAssign => @debug.Repr::ctor("TModAssign", [])
    TAltAssign => @debug.Repr::ctor("TAltAssign", [])
    TAnd => @debug.Repr::ctor("TAnd", [])
    TOr => @debug.Repr::ctor("TOr", [])
    TNot => @debug.Repr::ctor("TNot", [])
    TIf => @debug.Repr::ctor("TIf", [])
    TThen => @debug.Repr::ctor("TThen", [])
    TElse => @debug.Repr::ctor("TElse", [])
    TElif => @debug.Repr::ctor("TElif", [])
    TEnd => @debug.Repr::ctor("TEnd", [])
    TAs => @debug.Repr::ctor("TAs", [])
    TReduce => @debug.Repr::ctor("TReduce", [])
    TForeach => @debug.Repr::ctor("TForeach", [])
    TTry => @debug.Repr::ctor("TTry", [])
    TCatch => @debug.Repr::ctor("TCatch", [])
    TDef => @debug.Repr::ctor("TDef", [])
    TEof => @debug.Repr::ctor("TEof", [])
  }
}
