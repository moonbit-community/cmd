///|
pub fn Expression::contains_prune(self : Expression) -> Bool {
  match self {
    Prune => true
    Not(inner) => inner.contains_prune()
    And(left, right) | Or(left, right) =>
      left.contains_prune() || right.contains_prune()
    _ => false
  }
}

///|
fn Expression::has_effects(self : Expression) -> Bool {
  match self {
    Action(_) | Prune => true
    Not(inner) => inner.has_effects()
    And(left, right) | Or(left, right) =>
      left.has_effects() || right.has_effects()
    _ => false
  }
}

///|
fn Expression::collect_chain(
  self : Expression,
  conjunction : Bool,
  terms : Array[Expression],
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
fn order_find_group(
  group : Array[Expression],
  ordered : Array[Expression],
) -> Unit {
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
pub fn Expression::optimize(self : Expression) -> Expression {
  match self {
    And(_, _) | Or(_, _) => {
      let conjunction = self is And(_, _)
      let terms : Array[Expression] = []
      self.collect_chain(conjunction, terms)
      let group : Array[Expression] = []
      let ordered : Array[Expression] = []
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
