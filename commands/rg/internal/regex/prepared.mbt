///|
// Strategy: rg-deferred-storage
// NFA compilation remains eager so constructor errors keep their timing.
// Only non-raising engine storage is deferred until the selected route needs it.
priv enum DeferredEngine[A] {
  Pending(@automata.NFA)
  Prepared(A)
}

///|
fn Regex::pikevm_engine(self : Regex) -> @automata.PikeVM {
  match self.pikevm {
    Prepared(engine) => engine
    Pending(nfa) => {
      let engine = @automata.PikeVM::new(nfa)
      self.pikevm = Prepared(engine)
      engine
    }
  }
}

///|
fn Regex::reverse_engine(self : Regex) -> @automata.LazyDFA {
  match self.rev {
    Prepared(engine) => engine
    Pending(nfa) => {
      let engine = @automata.LazyDFA::new(
        nfa,
        match_all=true,
        state_limit=self.dfa_state_limit,
      )
      self.rev = Prepared(engine)
      engine
    }
  }
}

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
