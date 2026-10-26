///|
/// A sparse set of state IDs with insertion order iteration.
priv struct SparseSet {
  dense : FixedArray[Int32]
  sparse : FixedArray[Int32]
  mut len : Int32
}

///|
fn SparseSet::new(capacity : Int32) -> SparseSet {
  {
    dense: FixedArray::make(capacity, 0),
    sparse: FixedArray::make(capacity, 0),
    len: 0,
  }
}

///|
fn SparseSet::contains(self : SparseSet, id : Int32) -> Bool {
  let i = self.sparse[id]
  i < self.len && self.dense[i] == id
}

///|
/// Inserts the id, returning false if it was already present.
fn SparseSet::insert(self : SparseSet, id : Int32) -> Bool {
  if self.contains(id) {
    return false
  }
  self.dense[self.len] = id
  self.sparse[id] = self.len
  self.len += 1
  true
}

///|
fn SparseSet::clear(self : SparseSet) -> Unit {
  self.len = 0
}

///|
priv struct ActiveStates {
  set : SparseSet
  slots : FixedArray[Int32]
  slots_per_state : Int32
}

///|
fn ActiveStates::new(nstates : Int32, slots_per_state : Int32) -> ActiveStates {
  {
    set: SparseSet::new(nstates),
    slots: FixedArray::make(nstates * slots_per_state, -1),
    slots_per_state,
  }
}

///|
priv enum Frame {
  Explore(Int32)
  RestoreCapture(Int32, Int32)
}

///|
/// A PikeVM: an NFA simulation that supports capture groups and runs in
/// time linear in the size of the haystack.
pub struct PikeVM {
  nfa : NFA
  priv mut hs : Int32
  priv mut he : Int32
  priv mut curr : ActiveStates
  priv mut next : ActiveStates
  priv stack : Array[Frame]
  priv cache_slots : Int32
}

///|
pub fn PikeVM::new(nfa : NFA) -> PikeVM {
  let n = nfa.states.length()
  let slots = nfa.group_len * 2
  {
    nfa,
    hs: 0,
    he: 0,
    curr: ActiveStates::new(n, slots),
    next: ActiveStates::new(n, slots),
    stack: [],
    cache_slots: slots,
  }
}

///|
pub fn PikeVM::nfa(self : PikeVM) -> NFA {
  self.nfa
}

///|
/// Executes a leftmost-first search for a match in `hay[start:end]`, where
/// the haystack is `hay[hs:he]`. Capture positions are written into
/// `slots` (which may be shorter than the number of slots in the regex).
/// Returns true if a match was found.
pub fn PikeVM::search_slots(
  self : PikeVM,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  start : Int32,
  end : Int32,
  anchored : Bool,
  earliest : Bool,
  slots : FixedArray[Int32],
  pre? : Prefilter,
) -> Bool {
  self.hs = hs
  self.he = he
  let nslots = if slots.length() < self.cache_slots {
    slots.length()
  } else {
    self.cache_slots
  }
  let n = self.nfa.states.length()
  // Use a smaller slot table when fewer slots are requested.
  if self.curr.slots_per_state != nslots {
    self.curr = ActiveStates::new(n, nslots)
    self.next = ActiveStates::new(n, nslots)
  }
  self.curr.set.clear()
  self.next.set.clear()
  let scratch = FixedArray::make(nslots, -1)
  let mut matched = false
  let start_id = self.nfa.start_anchored
  let mut at = start
  while at <= end {
    if self.curr.set.len == 0 {
      if matched {
        break
      }
      if anchored && at > start {
        break
      }
      if !anchored && pre is Some(p) {
        match p.find_start(hay, at, end) {
          -1 => break
          s => at = s
        }
      }
    }
    if !matched && (!anchored || at == start) {
      for i in 0..<nslots {
        scratch[i] = -1
      }
      self.epsilon_closure(scratch, self.curr, hay, at, start_id)
    }
    if self.nexts(hay, end, at, slots, nslots) {
      matched = true
    }
    if earliest && matched {
      break
    }
    let tmp = self.curr
    self.curr = self.next
    self.next = tmp
    self.next.set.clear()
    at += 1
  }
  matched
}

///|
fn PikeVM::nexts(
  self : PikeVM,
  hay : FixedArray[Byte],
  end : Int32,
  at : Int32,
  slots : FixedArray[Int32],
  nslots : Int32,
) -> Bool {
  let curr = self.curr
  let set = curr.set
  for i in 0..<set.len {
    let sid = set.dense[i]
    match self.nfa.states[sid] {
      Match => {
        let base = sid * nslots
        for j in 0..<nslots {
          slots[j] = curr.slots[base + j]
        }
        return true
      }
      ByteRange(lo, hi, next) =>
        if at < end {
          let b = hay[at].to_int()
          if b >= lo && b <= hi {
            self.closure_from_state(sid, hay, at + 1, next, nslots)
          }
        }
      Sparse(ts) =>
        if at < end {
          let b = hay[at].to_int()
          for t in ts {
            if b < t.start {
              break
            }
            if b <= t.end {
              self.closure_from_state(sid, hay, at + 1, t.next, nslots)
              break
            }
          }
        }
      _ => ()
    }
  }
  false
}

///|
fn PikeVM::closure_from_state(
  self : PikeVM,
  sid : Int32,
  hay : FixedArray[Byte],
  at : Int32,
  next : Int32,
  nslots : Int32,
) -> Unit {
  // Copy the thread's slots into a scratch buffer, since the closure
  // mutates them in place.
  let base = sid * nslots
  let scratch = FixedArray::make(nslots, -1)
  for j in 0..<nslots {
    scratch[j] = self.curr.slots[base + j]
  }
  self.epsilon_closure(scratch, self.next, hay, at, next)
}

///|
fn PikeVM::epsilon_closure(
  self : PikeVM,
  slots : FixedArray[Int32],
  target : ActiveStates,
  hay : FixedArray[Byte],
  at : Int32,
  sid : Int32,
) -> Unit {
  let stack = self.stack
  stack.push(Explore(sid))
  while stack.pop() is Some(frame) {
    match frame {
      RestoreCapture(slot, pos) => slots[slot] = pos
      Explore(sid) => {
        let mut sid = sid
        while true {
          if !target.set.insert(sid) {
            break
          }
          match self.nfa.states[sid] {
            Fail | Match | ByteRange(_, _, _) | Sparse(_) => {
              let base = sid * target.slots_per_state
              for j in 0..<target.slots_per_state {
                target.slots[base + j] = slots[j]
              }
              break
            }
            Look(look, next) => {
              if !look_matches(look, hay, self.hs, self.he, at) {
                break
              }
              sid = next
            }
            Union(alts) => {
              if alts.is_empty() {
                break
              }
              for i = alts.length() - 1; i >= 1; i = i - 1 {
                stack.push(Explore(alts[i]))
              }
              sid = alts[0]
            }
            BinaryUnion(a, b) => {
              stack.push(Explore(b))
              sid = a
            }
            Capture(next~, slot~, ..) => {
              if slot < slots.length() {
                stack.push(RestoreCapture(slot, slots[slot]))
                slots[slot] = at
              }
              sid = next
            }
          }
        }
      }
    }
  }
}
