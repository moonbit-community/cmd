///|
priv struct ReferenceLimit {
  pc : Int32
  position : Int32
  left : Int32
  right : Int32
} derive(Eq, Hash)

///|
priv struct Sift {
  pattern : Pattern
  value : StringView
  original : Array[Map[Int32, Bool]]
  cache : CandidateCache
  states : Array[Map[Int32, Bool]]
  limited : Array[Map[Int32, Bool]]
  active : Map[(Int32, Int32, Array[ReferenceLimit]), Bool]
}

///|
fn Sift::epsilon(self : Sift, pc : Int32, position : Int32) -> Map[Int32, Bool] {
  let nodes : Map[Int32, Bool] = Map([])
  self.pattern.epsilon_nodes(self.value, position, pc, nodes)
  nodes
}

///|
fn Sift::region(
  self : Sift,
  pc : Int32,
  position : Int32,
  limit : ReferenceLimit,
  visited : Array[Int32],
) -> Int32 {
  if position < limit.left {
    return -1
  }
  if position > limit.right {
    return 1
  }
  let at_left = position == limit.left
  let at_right = position == limit.right
  if !at_left && !at_right {
    return 0
  }
  let group = match self.pattern.program[limit.pc] {
    Reference(group, _) => group
    _ => abort("reference limit")
  }
  let ordered = self.pattern.ordered_nodes(self.epsilon(pc, position))
  for node in ordered {
    match self.pattern.program[node] {
      Save(slot, _) if at_left && slot == group * 2 => return -1
      Save(slot, _) if at_right && slot == group * 2 + 1 => return 0
      SaveOptional(capture, _) if at_right && capture == group => return 0
      Reference(_, _) =>
        if self.cache.contains((node, position)) {
          let next = self.pattern.empty_next[node]
          if visited.contains(next) {
            return if at_left { -1 } else { 0 }
          }
          let visiting = visited.copy()
          visiting.push(next)
          let region = self.region(next, position, limit, visiting)
          if (at_left && region == -1) || (at_right && region == 0) {
            return region
          }
        }
      _ => ()
    }
  }
  if at_right {
    1
  } else {
    0
  }
}

///|
fn Sift::permits(
  self : Sift,
  from : (Int32, Int32),
  to : (Int32, Int32),
  limits : Array[ReferenceLimit],
) -> Bool {
  limits.all(limit => {
    self.region(from.0, from.1, limit, [from.0]) ==
    self.region(to.0, to.1, limit, [to.0])
  })
}

///|
fn Sift::remove_sources(
  self : Sift,
  node : Int32,
  position : Int32,
  nodes : Map[Int32, Bool],
) -> Unit {
  let inverse : Map[Int32, Bool] = Map([])
  for candidate in self.original[position].keys() {
    if self.epsilon(candidate, position).contains(node) {
      inverse[candidate] = true
    }
  }
  let except : Map[Int32, Bool] = Map([])
  for candidate in inverse.keys() {
    if candidate == node {
      continue
    }
    let destinations = match self.pattern.program[candidate] {
      Split(a, b) => [a, b]
      Save(_, next) | SaveOptional(_, next) | Assert(_, next) => [next]
      _ => []
    }
    if destinations.any(next => !inverse.contains(next) && nodes.contains(next)) {
      for ancestor in self.original[position].keys() {
        if self.epsilon(ancestor, position).contains(candidate) {
          except[ancestor] = true
        }
      }
    }
  }
  for candidate in inverse.keys() {
    if !except.contains(candidate) {
      nodes.remove(candidate)
    }
  }
}

///|
fn Sift::constrain(
  self : Sift,
  position : Int32,
  nodes : Map[Int32, Bool],
  limits : Array[ReferenceLimit],
) -> Unit {
  for limit in limits {
    if position <= limit.left || position > limit.position {
      continue
    }
    let group = match self.pattern.program[limit.pc] {
      Reference(group, _) => group
      _ => abort("reference limit")
    }
    if position == limit.right {
      let mut opening = -1
      let mut closing = -1
      let ordered = self.pattern.ordered_nodes(nodes)
      for pc in ordered {
        match self.pattern.program[pc] {
          Save(slot, _) if slot == group * 2 => opening = pc
          Save(slot, _) if slot == group * 2 + 1 => closing = pc
          SaveOptional(capture, _) if capture == group => closing = pc
          _ => ()
        }
      }
      if opening >= 0 {
        self.remove_sources(opening, position, nodes)
      }
      if closing >= 0 {
        for candidate in nodes.keys().to_array() {
          if !self.epsilon(candidate, position).contains(closing) &&
            !self.epsilon(closing, position).contains(candidate) {
            self.remove_sources(candidate, position, nodes)
          }
        }
      }
    } else {
      for candidate in nodes.keys().to_array() {
        let removes = match self.pattern.program[candidate] {
          Save(slot, _) => slot / 2 == group
          SaveOptional(capture, _) => capture == group
          _ => false
        }
        if removes {
          self.remove_sources(candidate, position, nodes)
        }
      }
    }
  }
}

///|
// Each reference adds its capture interval while tracing predecessors.
// Limited alternatives share the byte-position log, preserving the separate
// candidate-pruning and register-selection phases of GNU regexec.
fn Sift::backward(
  self : Sift,
  last_node : Int32,
  end : Int32,
  limits : Array[ReferenceLimit],
) -> Unit {
  let key = (last_node, end, limits)
  if self.active.contains(key) {
    return
  }
  self.active[key] = true
  for position = end; position >= 0; position = position - 1 {
    let nodes : Map[Int32, Bool] = Map([])
    if position == end {
      nodes[last_node] = true
    } else {
      for pc in self.original[position].keys() {
        if self.pattern.byte_next(self.value, pc, position) is Some(next) &&
          self.states[position + 1].contains(next) &&
          self.permits((pc, position), (next, position + 1), limits) {
          nodes[pc] = true
        }
      }
    }
    if !nodes.is_empty() {
      let destinations = nodes.keys().to_array()
      for pc in self.original[position].keys() {
        if destinations.any(destination => {
            self.epsilon(pc, position).contains(destination)
          }) {
          nodes[pc] = true
        }
      }
      self.constrain(position, nodes, limits)
    }
    self.states[position] = nodes
    let ordered = self.pattern.ordered_nodes(self.original[position])
    for pc in ordered {
      if pc == last_node && position == end {
        continue
      }
      guard self.pattern.program[pc] is Reference(_, consuming_next) else {
        continue
      }
      guard self.cache.get((pc, position)) is Some(spans) else { continue }
      for (left, right) in spans {
        let destination = position + right - left
        let next = if left == right {
          self.pattern.empty_next[pc]
        } else {
          consuming_next
        }
        if destination > end ||
          !self.states[destination].contains(next) ||
          !self.permits((pc, position), (next, destination), limits) {
          continue
        }
        let limit = ReferenceLimit::{ pc, position, left, right, }
        let nested = limits.copy()
        if !nested.contains(limit) {
          nested.push(limit)
        }
        let previous = self.states[position]
        self.backward(pc, position, nested)
        for index in 0..<=position {
          for candidate in self.states[index].keys() {
            self.limited[index][candidate] = true
          }
        }
        self.states[position] = previous
      }
    }
  }
  self.active.remove(key)
}

///|
fn Pattern::sift_candidates(
  self : Pattern,
  value : StringView,
  start : Int32,
  end : Int32,
  whole : Bool,
  word : Bool,
  cache : CandidateCache,
  log : Array[Map[Int32, Bool]],
) -> (Int32, Int32, Array[Map[Int32, Bool]])? {
  for last = end; last >= start; last = last - 1 {
    if !accepted(value, start, last, whole, word) {
      continue
    }
    let terminals = self
      .ordered_nodes(log[last])
      .filter(pc => self.program[pc] is Accept)
    if terminals.is_empty() {
      continue
    }
    // GNU's halt lookup returns the first program node if no constrained halt
    // survives at a shorter endpoint. Register selection still decides success.
    let mut terminal = self.entry
    for candidate in terminals {
      if self.allows(value, candidate, last) {
        terminal = candidate
        break
      }
    }
    let sift = Sift::{
      pattern: self,
      value,
      original: log,
      cache,
      states: Array::makei(last + 1, _ => Map([])),
      limited: Array::makei(last + 1, _ => Map([])),
      active: Map([]),
    }
    sift.backward(terminal, last, [])
    if sift.states[start].is_empty() && sift.limited[start].is_empty() {
      continue
    }
    for index in 0..<=last {
      for node in sift.limited[index].keys() {
        sift.states[index][node] = true
      }
    }
    return Some((last, terminal, sift.states))
  }
  None
}
