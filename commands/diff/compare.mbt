///|
struct Line {
  value : String
  terminated : Bool
} derive(Eq, Debug)

///|
enum Edit {
  Equal(Line)
  Remove(Line)
  Add(Line)
} derive(Eq, Debug)

///|
fn lines(data : Bytes) -> Array[Line] {
  let text = @bytere.text(data)
  let result : Array[Line] = []
  let mut start = 0
  for i in 0..<text.length() {
    if text[i] == '\n' {
      result.push({ value: text[start:i].to_owned(), terminated: true, })
      start = i + 1
    }
  }
  if start < text.length() {
    result.push({ value: text[start:].to_owned(), terminated: false, })
  }
  result
}

///|
/// Myers's edit frontier retains only the furthest reachable point per diagonal.
/// Trace reconstruction preserves original byte records, including final LF.
fn edits(a : Array[Line], b : Array[Line]) -> Array[Edit] {
  let n = a.length()
  let m = b.length()
  let frontier : Map[Int32, Int32] = { 1: 0 }
  let trace : Array[Map[Int32, Int32]] = []
  let mut distance = 0
  let mut done = false
  while distance <= n + m && !done {
    trace.push(Map::from_array(frontier.iter().collect()))
    for diagonal = -distance; diagonal <= distance; diagonal = diagonal + 2 {
      let left = frontier.get(diagonal - 1).unwrap_or(-1)
      let right = frontier.get(diagonal + 1).unwrap_or(-1)
      let mut x = if diagonal == -distance ||
        (diagonal != distance && left < right) {
        right
      } else {
        left + 1
      }
      let mut y = x - diagonal
      while x < n && y < m && a[x] == b[y] {
        x += 1
        y += 1
      }
      frontier[diagonal] = x
      if x >= n && y >= m {
        done = true
        break
      }
    }
    if !done {
      distance += 1
    }
  }
  let result : Array[Edit] = []
  let mut x = n
  let mut y = m
  for d = distance; d >= 0; d = d - 1 {
    let previous = trace[d]
    let diagonal = x - y
    let previous_diagonal = if diagonal == -d ||
      (
        diagonal != d &&
        previous.get(diagonal - 1).unwrap_or(-1) <
        previous.get(diagonal + 1).unwrap_or(-1)
      ) {
      diagonal + 1
    } else {
      diagonal - 1
    }
    let before_x = previous.get(previous_diagonal).unwrap_or(0)
    let before_y = before_x - previous_diagonal
    while x > before_x && y > before_y {
      x -= 1
      y -= 1
      result.push(Equal(a[x]))
    }
    if d > 0 {
      if x == before_x {
        y -= 1
        result.push(Add(b[y]))
      } else {
        x -= 1
        result.push(Remove(a[x]))
      }
    }
  }
  Array::makei(result.length(), i => result[result.length() - i - 1])
}

///|
fn record(out : StringBuilder, prefix : String, line : Line) -> Unit {
  out.write_string(prefix + line.value + "\n")
  if !line.terminated {
    out.write_string("\\ No newline at end of file\n")
  }
}

///|
fn range(start : Int32, count : Int32, unified : Bool) -> String {
  if count == 1 {
    (start + 1).to_string()
  } else if unified {
    "\{if count == 0 { start } else { start + 1 }},\{count}"
  } else if count == 0 {
    start.to_string()
  } else {
    "\{start + 1},\{start + count}"
  }
}

///|
fn normal(changes : Array[Edit]) -> Bytes {
  let output = StringBuilder()
  let mut i = 0
  let mut old_line = 0
  let mut new_line = 0
  while i < changes.length() {
    if changes[i] is Equal(_) {
      old_line += 1
      new_line += 1
      i += 1
      continue
    }
    let removed : Array[Line] = []
    let added : Array[Line] = []
    while i < changes.length() {
      match changes[i] {
        Equal(_) => break
        Remove(line) => removed.push(line)
        Add(line) => added.push(line)
      }
      i += 1
    }
    let operation = if removed.is_empty() {
      "a"
    } else if added.is_empty() {
      "d"
    } else {
      "c"
    }
    output.write_string(
      range(old_line, removed.length(), false) +
      operation +
      range(new_line, added.length(), false) +
      "\n",
    )
    for line in removed {
      record(output, "< ", line)
    }
    if !removed.is_empty() && !added.is_empty() {
      output.write_string("---\n")
    }
    for line in added {
      record(output, "> ", line)
    }
    old_line += removed.length()
    new_line += added.length()
  }
  @bytere.bytes(output.to_string())
}

///|
fn unified(
  changes : Array[Edit],
  context : Int32,
  label_a : String,
  label_b : String,
  context_format~ : Bool = false,
) -> Bytes {
  let output = StringBuilder()
  output.write_string(
    if context_format {
      "*** " + label_a + "\n--- " + label_b + "\n"
    } else {
      "--- " + label_a + "\n+++ " + label_b + "\n"
    },
  )
  let old_positions = [0]
  let new_positions = [0]
  for edit in changes {
    old_positions.push(
      old_positions.last().unwrap() + (if edit is Add(_) { 0 } else { 1 }),
    )
    new_positions.push(
      new_positions.last().unwrap() + (if edit is Remove(_) { 0 } else { 1 }),
    )
  }
  let mut position = 0
  while position < changes.length() {
    while position < changes.length() && changes[position] is Equal(_) {
      position += 1
    }
    if position == changes.length() {
      break
    }
    let start = if position > context { position - context } else { 0 }
    let mut last_change = position
    let mut scan = position
    while scan < changes.length() {
      if !(changes[scan] is Equal(_)) {
        last_change = scan
      } else if scan - last_change > context * 2 {
        break
      }
      scan += 1
    }
    let end = Int32::min(changes.length(), last_change + context + 1)
    let old_start = old_positions[start]
    let new_start = new_positions[start]
    if context_format {
      output.write_string(
        "***************\n*** " +
        range(old_start, old_positions[end] - old_start, false) +
        " ****\n",
      )
      context_side(output, changes[start:end], true)
      output.write_string(
        "--- " +
        range(new_start, new_positions[end] - new_start, false) +
        " ----\n",
      )
      context_side(output, changes[start:end], false)
    } else {
      output.write_string(
        "@@ -" +
        range(old_start, old_positions[end] - old_start, true) +
        " +" +
        range(new_start, new_positions[end] - new_start, true) +
        " @@\n",
      )
      for j in start..<end {
        match changes[j] {
          Equal(line) => record(output, " ", line)
          Remove(line) => record(output, "-", line)
          Add(line) => record(output, "+", line)
        }
      }
    }
    position = end
  }
  @bytere.bytes(output.to_string())
}

///|
fn context_side(
  output : StringBuilder,
  changes : ArrayView[Edit],
  old : Bool,
) -> Unit {
  if !changes
    .iter()
    .any(edit => if old { edit is Remove(_) } else { edit is Add(_) }) {
    return
  }
  let mut i = 0
  while i < changes.length() {
    match changes[i] {
      Equal(line) => {
        record(output, "  ", line)
        i += 1
      }
      _ => {
        let start = i
        let mut remove = false
        let mut add = false
        while i < changes.length() && !(changes[i] is Equal(_)) {
          if changes[i] is Remove(_) {
            remove = true
          } else {
            add = true
          }
          i += 1
        }
        let prefix = if remove && add {
          "! "
        } else if old {
          "- "
        } else {
          "+ "
        }
        for j in start..<i {
          match changes[j] {
            Remove(line) => if old { record(output, prefix, line) }
            Add(line) => if !old { record(output, prefix, line) }
            _ => ()
          }
        }
      }
    }
  }
}
