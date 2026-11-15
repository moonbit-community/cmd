///|
// Repeated lines are weak anchors inside otherwise unmatched regions. Keep
// stable borders and dense repeated runs while discarding sparse interior
// repetitions, as the default diffutils comparison does before Myers search.
fn discarded_lines(
  keys : Array[Int32],
  first : Int32,
  last : Int32,
  other_counts : Array[Int32],
) -> Array[Bool] {
  let length = last - first
  let mut scale = length
  let mut threshold = 5
  while scale >= 256 {
    scale = scale >> 2
    threshold = threshold << 1
  }
  let state = Array::make(length, 0)
  for i in 0..<length {
    let matches = other_counts[keys[first + i]]
    state[i] = if matches == 0 {
      1
    } else if matches > threshold {
      2
    } else {
      0
    }
  }
  let mut cursor = 0
  while cursor < length {
    if state[cursor] != 1 {
      if state[cursor] == 2 {
        state[cursor] = 0
      }
      cursor += 1
      continue
    }
    let begin = cursor
    while cursor < length && state[cursor] != 0 {
      cursor += 1
    }
    let finish = cursor
    let mut end = finish
    while end > begin && state[end - 1] == 2 {
      end -= 1
      state[end] = 0
    }
    let width = end - begin
    let mut repeated = 0
    for i in begin..<end {
      if state[i] == 2 {
        repeated += 1
      }
    }
    if repeated > width >> 2 {
      for i in begin..<end {
        if state[i] == 2 {
          state[i] = 0
        }
      }
      continue
    }
    let mut minimum = 2
    let mut exponent = width
    while exponent >= 16 {
      exponent = exponent >> 2
      minimum = (minimum - 1) * 2 + 1
    }
    let mut run = begin
    while run < end {
      if state[run] != 2 {
        run += 1
        continue
      }
      let start = run
      while run < end && state[run] == 2 {
        run += 1
      }
      if run - start >= minimum {
        for i in start..<run {
          state[i] = 0
        }
      }
    }
    for reverse in [false, true] {
      let mut solid = 0
      for step in 0..<width {
        let i = if reverse { end - step - 1 } else { begin + step }
        if step >= 8 && state[i] == 1 {
          break
        }
        match state[i] {
          2 => {
            state[i] = 0
            solid = 0
          }
          1 => solid += 1
          _ => solid = 0
        }
        if solid == 3 {
          break
        }
      }
    }
  }
  let discarded = Array::make(keys.length(), false)
  for i in 0..<length {
    discarded[first + i] = state[i] != 0
  }
  discarded
}
