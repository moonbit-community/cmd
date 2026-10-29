///|
// The adapter must prove that a match cannot include the record terminator.
pub fn Regex::boolean_stream_counter(
  self : Regex,
  term : Byte,
  required~ : Regex? = None,
) -> ((FixedArray[Byte], Int32, Int32, Bool) -> Int64)? {
  let pre = match required {
    Some(re) if re.pre_is_exact => re.pre
    _ => None
  }
  self.boolean_plan().map(plan => plan.stream_counter(term, pre?))
}

///|
// Prepared lazily after the command adapter selects a nonempty large block.
// The caller guarantees that matches cannot contain term, and that required
// is a mandatory-literal filter. Unsupported plans keep the existing engine.
pub fn Regex::count_boolean_lines(
  self : Regex,
  hay : FixedArray[Byte],
  start : Int32,
  end : Int32,
  term : Byte,
  required~ : Regex? = None,
) -> Int64? {
  let pre = match required {
    Some(re) if re.pre_is_exact => re.pre
    _ => None
  }
  self
  .boolean_plan()
  .map(plan => {
    if end - start > 262144 {
      plan.count_long_lines(hay, start, end, term, pre?)
    } else {
      plan.count_lines(hay, start, end, term, pre?)
    }
  })
}
