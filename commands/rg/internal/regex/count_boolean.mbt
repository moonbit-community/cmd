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
  if !self.count_plan_ready {
    self.count_plan = self.fwd.record_boolean()
    self.count_plan_ready = true
  }
  let pre = match required {
    Some(re) if re.pre_is_exact => re.pre
    _ => None
  }
  self.count_plan.map(plan => {
    if end - start > 262144 {
      plan.count_long_lines(hay, start, end, term, pre?)
    } else {
      plan.count_lines(hay, start, end, term, pre?)
    }
  })
}
