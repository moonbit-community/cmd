///|
// Only the command's candidate-line discovery may use an arbitrary earliest
// endpoint. Captures, greedy endpoints and ordinary find_at retain their engine.
pub fn Regex::search_boolean_long(
  self : Regex,
  hay : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Int32? {
  if self.pre_is_exact {
    return None
  }
  let at = match self.pre {
    Some(filter) =>
      filter.find(hay, start, end).map(pair => pair.0).unwrap_or(-1)
    None => start
  }
  if at < 0 {
    return Some(-1)
  }
  self.boolean_plan().map(plan => plan.search_long_half(hay, at, end))
}
