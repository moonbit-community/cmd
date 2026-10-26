///|
/// A single test case from the regex crate's test corpus.
pub(all) struct TestCase {
  name : String
  regex : String
  haystack : Bytes
  /// Each match is a list of capture group spans (group 0 first).
  matches : Array[Array[(Int32, Int32)?]]
  compiles : Bool
  anchored : Bool
  case_insensitive : Bool
  unicode : Bool
  utf8 : Bool
  match_limit : Int32?
  bounds : (Int32, Int32)?
  line_terminator : Int32?
}
