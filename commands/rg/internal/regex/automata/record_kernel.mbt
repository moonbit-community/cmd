///|
// All consumers use absorbing accepting rows. Endpoint discovery alone replays
// an accepting four-byte group to recover the delayed exact match position.
#inline
fn wide_step4(
  table : FixedArray[Int32],
  hay : FixedArray[Byte],
  state : Int32,
  at : Int32,
) -> Int32 {
  let state = table[state + hay[at].to_int()]
  let state = table[state + hay[at + 1].to_int()]
  let state = table[state + hay[at + 2].to_int()]
  table[state + hay[at + 3].to_int()]
}

///|
#valtype
priv struct WideProbe {
  offset : Int32
  accelerating : Bool
}

///|
#inline
fn WideBoolean::probe_exit(
  self : WideBoolean,
  hay : FixedArray[Byte],
  at : Int32,
  end : Int32,
  state : Int32,
  observe_density : Bool,
) -> WideProbe {
  // Callers retain the hot-loop eligibility guard: no result transfer or
  // mutable stream update is needed when the state has changed or probing ended.
  if self.accelerators[state / 256] is Some(filter) {
    let next = filter.find_start(hay, at, end)
    if next < 0 {
      return { offset: end, accelerating: true, }
    }
    return {
      offset: next,
      accelerating: !observe_density || next - at >= boolean_sparse_exit_bytes,
    }
  }
  { offset: at, accelerating: true, }
}
