///|
// Strategy: rg-wide-boolean
// Expand only for oversized records. Direct byte rows remove the class lookup;
// an absorbing accepting row permits four transitions between match checks.
priv struct WideBoolean {
  transitions : FixedArray[Int32]
  eof : FixedArray[Bool]
  start : Int32
  accept : Int32
  accelerators : FixedArray[Prefilter?]
}

///|
fn RecordBoolean::wide_rows(
  self : RecordBoolean,
) -> (FixedArray[Int32], FixedArray[Bool], Int32, Int32) {
  let states = self.transitions.length() / self.stride
  let accept = states * 256
  let table = FixedArray::make((states + 1) * 256, accept)
  let eof = FixedArray::make(states + 1, true)
  for state in 0..<states {
    let row = state * self.stride
    eof[state] = self.transitions[row + self.stride - 1] >= MATCH_TAG
    for byte in 0..<256 {
      let next = self.transitions[row + self.classes[byte]]
      table[state * 256 + byte] = if next >= MATCH_TAG {
        accept
      } else if next < 0 {
        // Unexpanded accepting states are replaced by the accepting row.
        0
      } else {
        next / self.stride * 256
      }
    }
  }
  (table, eof, self.start / self.stride * 256, accept)
}

///|
fn RecordBoolean::wide_plan(self : RecordBoolean) -> WideBoolean {
  if self.wide is Some(plan) {
    return plan
  }
  let (table, eof, start, accept) = self.wide_rows()
  let alphabet : Array[Int32] = []
  let seen = FixedArray::make(self.stride, false)
  for byte in 0..<256 {
    let unit = self.classes[byte]
    if !seen[unit] {
      seen[unit] = true
      alphabet.push(byte)
    }
  }
  let (table, eof, start, accept) = minimize_boolean_rows(
    table, eof, start, accept, alphabet,
  ).unwrap_or((table, eof, start, accept))
  let states = eof.length()
  let accelerators : FixedArray[Prefilter?] = FixedArray::make(states, None)
  for state in 0..<states {
    let exits : Array[Byte] = []
    let members = FixedArray::make(256, false)
    for byte in 0..<256 {
      if table[state * 256 + byte] != state * 256 {
        exits.push(byte.to_byte())
        members[byte] = true
      }
    }
    accelerators[state] = match exits {
      [a] => Some(Byte(a))
      [a, b] => Some(Bytes2(a, b))
      [a, b, c] => Some(Bytes3(a, b, c))
      _ if exits.length() > 3 && exits.length() < 256 =>
        Some(ByteSet(@memchr.ByteSetFinder::new(members)))
      _ => None
    }
  }
  let plan = { transitions: table, eof, start, accept, accelerators, }
  self.wide = Some(plan)
  plan
}

///|
// Return an exact earliest end offset. The accepting row is absorbing, so a
// matching group of four is replayed once to recover the delayed DFA endpoint.
pub fn RecordBoolean::search_long_half(
  self : RecordBoolean,
  hay : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Int32 {
  let plan = self.wide_plan()
  let table = plan.transitions
  let mut state = plan.start
  let mut at = start
  let mut accelerating = true
  while end - at >= 4 {
    let previous = state
    state = wide_step4(table, hay, state, at)
    if state == plan.accept {
      state = previous
      for offset in 0..<4 {
        state = table[state + hay[at + offset].to_int()]
        if state == plan.accept {
          return at + offset
        }
      }
    }
    at += 4
    if accelerating &&
      state == previous &&
      end - at >= boolean_probe_window_bytes {
      let probe = plan.probe_exit(hay, at, end, state, true)
      at = probe.offset
      accelerating = probe.accelerating
    }
  }
  while at < end {
    state = table[state + hay[at].to_int()]
    if state == plan.accept {
      return at
    }
    at += 1
  }
  if plan.eof[state / 256] {
    end
  } else {
    -1
  }
}

///|
pub fn RecordBoolean::count_long_lines(
  self : RecordBoolean,
  hay : FixedArray[Byte],
  start : Int32,
  end : Int32,
  term : Byte,
  pre? : Prefilter,
) -> Int64 {
  let plan = self.wide_plan()
  let table = plan.transitions
  let mut count = 0L
  let mut at = start
  while at < end {
    if pre is Some(filter) {
      let candidate = filter.find_span(hay, at, end)
      if candidate == NO_SPAN {
        break
      }
      let previous = @memchr.memrchr(term, hay, at, span_start(candidate))
      if previous >= 0 {
        at = previous + 1
      }
    }
    let next_term = @memchr.memchr(term, hay, at, end)
    let line_end = if next_term < 0 { end } else { next_term }
    let mut state = plan.start
    let mut i = at
    let mut accelerating = true
    while line_end - i >= 4 && state != plan.accept {
      let previous = state
      state = wide_step4(table, hay, state, i)
      i += 4
      if accelerating &&
        state == previous &&
        line_end - i >= boolean_probe_window_bytes {
        let probe = plan.probe_exit(hay, i, line_end, state, true)
        i = probe.offset
        accelerating = probe.accelerating
      }
    }
    while i < line_end && state != plan.accept {
      state = table[state + hay[i].to_int()]
      i += 1
    }
    if state == plan.accept || plan.eof[state / 256] {
      count += 1L
    }
    at = if next_term < 0 { end } else { line_end + 1 }
  }
  count
}
