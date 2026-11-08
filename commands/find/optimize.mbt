///|
fn FindExpr::contains_prune(self : FindExpr) -> Bool {
  match self {
    Prune => true
    Not(inner) => inner.contains_prune()
    And(left, right) | Or(left, right) =>
      left.contains_prune() || right.contains_prune()
    _ => false
  }
}

///|
fn FindExpr::has_effects(self : FindExpr) -> Bool {
  match self {
    Action(_) | Prune => true
    Not(inner) => inner.has_effects()
    And(left, right) | Or(left, right) =>
      left.has_effects() || right.has_effects()
    _ => false
  }
}

///|
fn FindExpr::collect_chain(
  self : FindExpr,
  conjunction : Bool,
  terms : Array[FindExpr],
) -> Unit {
  match self {
    And(left, right) if conjunction => {
      left.collect_chain(conjunction, terms)
      terms.push(right)
    }
    Or(left, right) if !conjunction => {
      left.collect_chain(conjunction, terms)
      terms.push(right)
    }
    _ => terms.push(self)
  }
}

///|
// GNU's default optimization promotes name/path and constant primaries inside
// effect-free AND/OR groups. Do not move queries across actions or prune, or
// treat negation and compound subexpressions as cost-free primaries. The left
// operator chain is flattened; a right compound term retains its own group.
fn order_find_group(group : Array[FindExpr], ordered : Array[FindExpr]) -> Unit {
  for expression in group {
    if expression is (Name(_) | Path(_) | Always(_)) {
      ordered.push(expression)
    }
  }
  for expression in group {
    if !(expression is (Name(_) | Path(_) | Always(_))) {
      ordered.push(expression)
    }
  }
  group.clear()
}

///|
fn FindExpr::optimize(self : FindExpr) -> FindExpr {
  match self {
    And(_, _) | Or(_, _) => {
      let conjunction = self is And(_, _)
      let terms : Array[FindExpr] = []
      self.collect_chain(conjunction, terms)
      let group : Array[FindExpr] = []
      let ordered : Array[FindExpr] = []
      for term in terms {
        let term = term.optimize()
        if term.has_effects() {
          order_find_group(group, ordered)
          ordered.push(term)
        } else {
          group.push(term)
        }
      }
      order_find_group(group, ordered)
      let mut result = ordered[0]
      for index in 1..<ordered.length() {
        result = if conjunction {
          And(result, ordered[index])
        } else {
          Or(result, ordered[index])
        }
      }
      result
    }
    Not(inner) => Not(inner.optimize())
    _ => self
  }
}
