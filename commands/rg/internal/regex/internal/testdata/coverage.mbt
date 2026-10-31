///|
/// A declared corpus dialect exclusion, independent of parse success.
pub fn exclusion(tc : TestCase, meta~ : Bool = false) -> String? {
  if tc.name.has_prefix("regex-lite/") {
    Some("regex-lite dialect")
  } else if tc.line_terminator is Some(_) {
    Some("custom line terminator")
  } else if meta && tc.anchored {
    Some("anchored meta search")
  } else {
    None
  }
}

///|
/// Expected rejection is evidence only when the parser actually rejects.
pub fn compile_expectation(tc : TestCase, parsed~ : Bool) -> String? {
  if tc.compiles && !parsed {
    Some("\{tc.name}: unexpectedly failed to parse \{tc.regex}")
  } else if !tc.compiles && parsed {
    Some("\{tc.name}: unexpectedly parsed invalid pattern \{tc.regex}")
  } else {
    None
  }
}
