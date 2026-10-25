///|
type CandidateCache = Map[(Int32, Int32), Array[(Int32, Int32)]]

///|
fn Pattern::epsilon_nodes(
  self : Pattern,
  value : StringView,
  position : Int32,
  node : Int32,
  nodes : Map[Int32, Bool],
) -> Unit {
  let pending = [node]
  while pending.pop() is Some(pc) {
    if nodes.contains(pc) || !self.previous_allows(value, pc, position) {
      continue
    }
    nodes[pc] = true
    match self.program[pc] {
      Split(first, second) => {
        pending.push(second)
        pending.push(first)
      }
      Save(_, next) | SaveOptional(_, next) => pending.push(next)
      Assert(assertion, next) =>
        if assertion is (End | LineEnd) || assertion.holds(value, position) {
          pending.push(next)
        }
      _ => ()
    }
  }
}

///|
fn Pattern::byte_next(
  self : Pattern,
  value : StringView,
  pc : Int32,
  position : Int32,
) -> Int32? {
  if position >= value.length() || !self.allows(value, pc, position) {
    return None
  }
  match self.program[pc] {
    Byte(c, next) =>
      if value[position].to_int() == c {
        Some(next)
      } else {
        None
      }
    Any(next) => Some(next)
    Class(members, next) =>
      if value[position].to_int() < 256 && members[value[position].to_int()] {
        Some(next)
      } else {
        None
      }
    _ => None
  }
}

///|
fn Pattern::arrival(
  self : Pattern,
  value : StringView,
  from : (Int32, Int32),
  to : (Int32, Int32),
  group : Int32,
  stop_close : Bool,
  cache : CandidateCache,
) -> Bool {
  let stack = [from]
  let seen : Map[(Int32, Int32), Bool] = Map([])
  while stack.pop() is Some((pc, position)) {
    if position > to.1 ||
      seen.contains((pc, position)) ||
      !self.previous_allows(value, pc, position) {
      continue
    }
    seen[(pc, position)] = true
    if (pc, position) == to {
      return true
    }
    match self.program[pc] {
      Split(first, second) => {
        stack.push((second, position))
        stack.push((first, position))
      }
      Save(slot, next) => {
        if slot / 2 == group && (slot % 2 == 1) == stop_close {
          continue
        }
        stack.push((next, position))
      }
      SaveOptional(capture, next) =>
        if capture != group || !stop_close {
          stack.push((next, position))
        }
      Assert(assertion, next) =>
        if assertion is (End | LineEnd) || assertion.holds(value, position) {
          stack.push((next, position))
        }
      Reference(_, next) =>
        if cache.get((pc, position)) is Some(spans) {
          for (left, right) in spans {
            stack.push(
              (
                if left == right {
                  self.empty_next[pc]
                } else {
                  next
                },
                position + right - left,
              ),
            )
          }
        }
      _ =>
        if self.byte_next(value, pc, position) is Some(next) {
          stack.push((next, position + 1))
        }
    }
  }
  false
}

///|
fn equal_reference(
  value : StringView,
  left : Int32,
  right : Int32,
  position : Int32,
  ignore_case : Bool,
) -> Bool {
  if position + right - left > value.length() {
    return false
  }
  if ignore_case {
    for offset in 0..<(right - left) {
      if ascii_fold(value[left + offset].to_int()) !=
        ascii_fold(value[position + offset].to_int()) {
        return false
      }
    }
    true
  } else {
    value[left:right] == value[position:position + right - left]
  }
}

///|
// Keep the ordered node set at each byte separately from capture registers.
// GNU selects the first closing node at a byte, then checks arrival without
// crossing another close/open of that group. Cache spans, not report tags.
fn Pattern::candidate_log(
  self : Pattern,
  value : StringView,
  start : Int32,
  whole : Bool,
  word : Bool,
) -> (CandidateCache, Int32?, Array[Map[Int32, Bool]]) {
  let log : Array[Map[Int32, Bool]] = Array::makei(value.length() + 1, _ => {
    Map([])
  })
  let pending : Array[Array[Int32]] = Array::makei(value.length() + 1, _ => [])
  let cache : CandidateCache = Map([])
  let tops : Array[(Int32, Int32)] = []
  let registered : Map[(Int32, Int32), Bool] = Map([])
  pending[start].push(self.entry)
  let mut end : Int32? = None
  for position in start..<=value.length() {
    let nodes = log[position]
    for pc in pending[position] {
      self.epsilon_nodes(value, position, pc, nodes)
    }
    if position == start {
      let mut changed = true
      while changed {
        changed = false
        for pc in nodes.keys().to_array() {
          if self.program[pc] is Reference(group, _) &&
            !nodes.contains(self.empty_next[pc]) {
            let mut closed = false
            for candidate in nodes.keys() {
              match self.program[candidate] {
                Save(slot, _) => if slot == group * 2 + 1 { closed = true }
                SaveOptional(capture, _) =>
                  if capture == group {
                    closed = true
                  }
                _ => ()
              }
            }
            if closed {
              let before = nodes.length()
              self.epsilon_nodes(value, position, self.empty_next[pc], nodes)
              changed = changed || before != nodes.length()
            }
          }
        }
      }
    }
    let mut previous_size = -1
    while previous_size != nodes.length() {
      previous_size = nodes.length()
      let ordered = self.ordered_nodes(nodes)
      for pc in ordered {
        if self.program[pc] is Save(slot, _) &&
          slot % 2 == 0 &&
          !registered.contains((pc, position)) {
          registered[(pc, position)] = true
          tops.push((pc, position))
        }
      }
      for pc in ordered {
        guard self.program[pc] is Reference(group, next) else { continue }
        if !cache.contains((pc, position)) {
          let spans : Array[(Int32, Int32)] = []
          for top in tops {
            guard self.program[top.0] is Save(slot, _) && slot == group * 2 else {
              continue
            }
            for right in top.1..<=position {
              if !equal_reference(
                  value,
                  top.1,
                  right,
                  position,
                  self.ignore_case,
                ) {
                break
              }
              let mut closing = -1
              for candidate in log[right].keys() {
                let closes = match self.program[candidate] {
                  Save(slot, _) => slot == group * 2 + 1
                  SaveOptional(capture, _) => capture == group
                  _ => false
                }
                if closes &&
                  (
                    closing < 0 ||
                    self.node_order(candidate) < self.node_order(closing)
                  ) {
                  closing = candidate
                }
              }
              if closing < 0 {
                continue
              }
              if self.arrival(value, top, (closing, right), group, true, cache) &&
                self.arrival(
                  value,
                  (closing, right),
                  (pc, position),
                  group,
                  false,
                  cache,
                ) {
                if !spans.contains((top.1, right)) {
                  spans.push((top.1, right))
                }
              }
            }
          }
          if !spans.is_empty() {
            cache[(pc, position)] = spans
          }
        }
        if cache.get((pc, position)) is Some(spans) {
          for (left, right) in spans {
            let destination = position + right - left
            if destination == position {
              self.epsilon_nodes(value, position, self.empty_next[pc], nodes)
            } else {
              pending[destination].push(next)
            }
          }
        }
      }
    }
    if nodes
      .keys()
      .any(pc => self.program[pc] is Accept && self.allows(value, pc, position)) &&
      accepted(value, start, position, whole, word) {
      end = Some(position)
    }
    for pc in nodes.keys() {
      if self.byte_next(value, pc, position) is Some(next) {
        pending[position + 1].push(next)
      }
    }
  }
  (cache, end, log)
}
