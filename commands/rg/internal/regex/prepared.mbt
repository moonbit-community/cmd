///|
// Strategy: rg-boolean-count
priv enum BooleanPlanCache {
  Uninitialized
  Declined
  Ready(@automata.RecordBoolean)
}

///|
// A decline is permanent for this immutable expression, whether unsupported or
// over budget. Each caller restarts its original semantic fallback on None.
fn Regex::boolean_plan(self : Regex) -> @automata.RecordBoolean? {
  if self.count_plan is Uninitialized {
    self.count_plan = match self.fwd.record_boolean() {
      Some(plan) => Ready(plan)
      None => Declined
    }
  }
  match self.count_plan {
    Ready(plan) => Some(plan)
    _ => None
  }
}
