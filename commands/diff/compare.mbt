///|
struct Line {
  value : BytesView
  terminated : Bool
} derive(Eq, Debug, Hash)

///|
enum Edit {
  Equal(Line)
  Remove(Line)
  Add(Line)
} derive(Eq, Debug)

///|
fn lines(data : Bytes) -> Array[Line] {
  let result : Array[Line] = []
  let mut start = 0
  for i in 0..<data.length() {
    if data[i] == b'\n' {
      result.push({ value: data[start:i], terminated: true, })
      start = i + 1
    }
  }
  if start < data.length() {
    result.push({ value: data[start:], terminated: false, })
  }
  result
}

///|
priv struct CompareOptions {
  ignore_case : Bool
  ignore_all_space : Bool
  ignore_space_change : Bool
  ignore_trailing_space : Bool
  strip_trailing_cr : Bool
  ignore_blank_lines : Bool
}

///|
fn compare_options(
  ignore_case~ : Bool = false,
  ignore_all_space~ : Bool = false,
  ignore_space_change~ : Bool = false,
  ignore_trailing_space~ : Bool = false,
  strip_trailing_cr~ : Bool = false,
  ignore_blank_lines~ : Bool = false,
) -> CompareOptions {
  {
    ignore_case,
    ignore_all_space,
    ignore_space_change,
    ignore_trailing_space,
    strip_trailing_cr,
    ignore_blank_lines,
  }
}

///|
fn whitespace(byte : Byte) -> Bool {
  byte == b' ' ||
  byte == b'\t' ||
  byte == b'\r' ||
  byte == b'\x0b' ||
  byte == b'\x0c'
}

///|
fn comparison_key(line : Line, options : CompareOptions) -> Line {
  let mut end = line.value.length()
  if options.strip_trailing_cr &&
    line.terminated &&
    end > 0 &&
    line.value[end - 1] == b'\r' {
    end -= 1
  }
  let ignore_space = options.ignore_all_space ||
    options.ignore_space_change ||
    options.ignore_trailing_space
  if ignore_space {
    while end > 0 && whitespace(line.value[end - 1]) {
      end -= 1
    }
  }
  let value = line.value[:end]
  let transformed = (
      options.ignore_case ||
      options.ignore_all_space ||
      options.ignore_space_change
    ) &&
    value
    .iter()
    .any(byte => {
      (options.ignore_case && byte >= b'A' && byte <= b'Z') ||
      (
        (options.ignore_all_space || options.ignore_space_change) &&
        whitespace(byte)
      )
    })
  if !transformed {
    return { value, terminated: line.terminated || ignore_space, }
  }
  let out = FixedArray::make(end, b'\x00')
  let mut length = 0
  let mut pending_space = false
  for byte in value {
    if whitespace(byte) {
      if options.ignore_all_space {
        continue
      }
      if options.ignore_space_change {
        pending_space = true
        continue
      }
    }
    if pending_space {
      out[length] = b' '
      length += 1
      pending_space = false
    }
    out[length] = if options.ignore_case && byte >= b'A' && byte <= b'Z' {
      (byte.to_int() + 32).to_byte()
    } else {
      byte
    }
    length += 1
  }
  {
    value: out.unsafe_reinterpret_as_bytes()[:length],
    terminated: line.terminated || ignore_space,
  }
}

///|
fn blank_line(line : Line, options : CompareOptions) -> Bool {
  let key = comparison_key(line, options)
  key.value.is_empty()
}

///|
fn identical_input_line(left : Line, right : Line, strip_cr : Bool) -> Bool {
  if left.terminated != right.terminated {
    return false
  }
  if !strip_cr || !left.terminated {
    return left.value == right.value
  }
  let left_end = left.value.length() -
    (if left.value.has_suffix(b"\r") { 1 } else { 0 })
  let right_end = right.value.length() -
    (if right.value.has_suffix(b"\r") { 1 } else { 0 })
  left.value[:left_end] == right.value[:right_end]
}

///|
fn changed(flags : Array[Bool], index : Int32) -> Bool {
  index >= 0 && index < flags.length() && flags[index]
}

///|
/// Equivalent records let a change slide without changing either reconstructed
/// input. Prefer joined groups and the latest corresponding group on both sides.
fn align_changes(
  keys : Array[Int32],
  flags : Array[Bool],
  other : Array[Bool],
  first : Int32,
  last : Int32,
) -> Unit {
  let mut at = first
  let mut counterpart = first
  while at < last {
    if !flags[at] {
      while changed(other, counterpart) {
        counterpart += 1
      }
      counterpart += 1
      at += 1
      continue
    }
    let mut begin = at
    while changed(flags, at) {
      at += 1
    }
    while changed(other, counterpart) {
      counterpart += 1
    }
    let mut anchor = last
    for ;; {
      let size = at - begin
      while begin > first && keys[begin - 1] == keys[at - 1] {
        begin -= 1
        at -= 1
        flags[begin] = true
        flags[at] = false
        while changed(flags, begin - 1) {
          begin -= 1
        }
        counterpart -= 1
        while changed(other, counterpart) {
          counterpart -= 1
        }
      }
      anchor = if changed(other, counterpart - 1) { at } else { last }
      while at < last && keys[begin] == keys[at] {
        flags[begin] = false
        flags[at] = true
        begin += 1
        at += 1
        while changed(flags, at) {
          at += 1
        }
        counterpart += 1
        while changed(other, counterpart) {
          anchor = at
          counterpart += 1
        }
      }
      if at - begin == size {
        break
      }
    }
    while at > anchor {
      begin -= 1
      at -= 1
      flags[begin] = true
      flags[at] = false
      counterpart -= 1
      while changed(other, counterpart) {
        counterpart -= 1
      }
    }
  }
}

///|
/// Bidirectional Myers frontiers meet on a shortest path. The two work arrays
/// are reused for every partition; the explicit partition stack holds no traces.
fn middle(
  a : Array[Int32],
  b : Array[Int32],
  first_a : Int32,
  last_a : Int32,
  first_b : Int32,
  last_b : Int32,
  forward : Array[Int32],
  backward : Array[Int32],
) -> (Int32, Int32) {
  let offset = b.length() + 1
  let low = first_a - last_b
  let high = last_a - first_b
  let mut fl = first_a - first_b
  let mut fh = fl
  let mut bl = last_a - last_b
  let mut bh = bl
  let odd = ((fl - bl) & 1) != 0
  forward[fl + offset] = first_a
  backward[bl + offset] = last_a
  for ;; {
    if fl > low {
      fl -= 1
      forward[fl - 1 + offset] = -1
    } else {
      fl += 1
    }
    if fh < high {
      fh += 1
      forward[fh + 1 + offset] = -1
    } else {
      fh -= 1
    }
    for diagonal = fh; diagonal >= fl; diagonal = diagonal - 2 {
      let before = forward[diagonal - 1 + offset]
      let after = forward[diagonal + 1 + offset]
      let mut x = if before < after { after } else { before + 1 }
      let mut y = x - diagonal
      while x < last_a && y < last_b && a[x] == b[y] {
        x += 1
        y += 1
      }
      forward[diagonal + offset] = x
      if odd &&
        diagonal >= bl &&
        diagonal <= bh &&
        backward[diagonal + offset] <= x {
        return (x, y)
      }
    }
    if bl > low {
      bl -= 1
      backward[bl - 1 + offset] = 2147483647
    } else {
      bl += 1
    }
    if bh < high {
      bh += 1
      backward[bh + 1 + offset] = 2147483647
    } else {
      bh -= 1
    }
    for diagonal = bh; diagonal >= bl; diagonal = diagonal - 2 {
      let before = backward[diagonal - 1 + offset]
      let after = backward[diagonal + 1 + offset]
      let mut x = if before < after { before } else { after - 1 }
      let mut y = x - diagonal
      while x > first_a && y > first_b && a[x - 1] == b[y - 1] {
        x -= 1
        y -= 1
      }
      backward[diagonal + offset] = x
      if !odd &&
        diagonal >= fl &&
        diagonal <= fh &&
        x <= forward[diagonal + offset] {
        return (x, y)
      }
    }
  }
}

///|
fn edits(
  a : Array[Line],
  b : Array[Line],
  options~ : CompareOptions = compare_options(),
  context~ : Int32 = 0,
) -> Array[Edit] {
  let mut common_prefix = 0
  while common_prefix < a.length() &&
        common_prefix < b.length() &&
        identical_input_line(
          a[common_prefix],
          b[common_prefix],
          options.strip_trailing_cr,
        ) {
    common_prefix += 1
  }
  let mut common_suffix = 0
  while common_suffix < a.length() - common_prefix &&
        common_suffix < b.length() - common_prefix &&
        identical_input_line(
          a[a.length() - common_suffix - 1],
          b[b.length() - common_suffix - 1],
          options.strip_trailing_cr,
        ) {
    common_suffix += 1
  }
  let first = (common_prefix - context).max(0)
  let ends = [
    (a.length() - common_suffix + context).min(a.length()),
    (b.length() - common_suffix + context).min(b.length()),
  ]
  let classes : Map[Line, Int32] = Map([])
  let keys : Array[Array[Int32]] = []
  for side, input in [a, b] {
    let values = Array::make(input.length(), -1)
    for i in first..<ends[side] {
      let key = comparison_key(input[i], options)
      let id = match classes.get(key) {
        Some(id) => id
        None => {
          let id = classes.length()
          classes[key] = id
          id
        }
      }
      values[i] = id
    }
    keys.push(values)
  }
  let counts = [
    Array::make(classes.length(), 0),
    Array::make(classes.length(), 0),
  ]
  for side in 0..<2 {
    for i in first..<ends[side] {
      counts[side][keys[side][i]] += 1
    }
  }
  let flags = [Array::make(a.length(), false), Array::make(b.length(), false)]
  let indexes : Array[Array[Int32]] = []
  let retained : Array[Array[Int32]] = []
  for side in 0..<2 {
    let index : Array[Int32] = []
    let values : Array[Int32] = []
    let discarded = discarded_lines(
      keys[side],
      first,
      ends[side],
      counts[1 - side],
    )
    for i in first..<ends[side] {
      let key = keys[side][i]
      if discarded[i] {
        flags[side][i] = true
      } else {
        index.push(i)
        values.push(key)
      }
    }
    indexes.push(index)
    retained.push(values)
  }
  let left = retained[0]
  let right = retained[1]
  let forward = Array::make(left.length() + right.length() + 3, 0)
  let backward = Array::make(forward.length(), 0)
  let pending = [(0, left.length(), 0, right.length())]
  while pending.pop() is Some((start_a, end_a, start_b, end_b)) {
    let mut start_a = start_a
    let mut start_b = start_b
    let mut end_a = end_a
    let mut end_b = end_b
    while start_a < end_a && start_b < end_b && left[start_a] == right[start_b] {
      start_a += 1
      start_b += 1
    }
    while start_a < end_a &&
          start_b < end_b &&
          left[end_a - 1] == right[end_b - 1] {
      end_a -= 1
      end_b -= 1
    }
    if start_a == end_a {
      for i in start_b..<end_b {
        flags[1][indexes[1][i]] = true
      }
    } else if start_b == end_b {
      for i in start_a..<end_a {
        flags[0][indexes[0][i]] = true
      }
    } else {
      let (x, y) = middle(
        left, right, start_a, end_a, start_b, end_b, forward, backward,
      )
      pending.push((x, end_a, y, end_b))
      pending.push((start_a, x, start_b, y))
    }
  }
  // Identical edges outside the requested context do not participate in either
  // matching or alignment. They remain unchanged records in the final script.
  align_changes(keys[0], flags[0], flags[1], first, ends[0])
  align_changes(keys[1], flags[1], flags[0], first, ends[1])
  let result : Array[Edit] = []
  let mut x = 0
  let mut y = 0
  while x < a.length() || y < b.length() {
    while changed(flags[0], x) {
      result.push(Remove(a[x]))
      x += 1
    }
    while changed(flags[1], y) {
      result.push(Add(b[y]))
      y += 1
    }
    if x < a.length() && y < b.length() {
      result.push(Equal(a[x]))
      x += 1
      y += 1
    }
  }
  result
}

///|
fn record(
  out : StringBuilder,
  prefix : String,
  line : Line,
  options~ : CompareOptions = compare_options(),
) -> Unit {
  let value = if options.strip_trailing_cr &&
    line.terminated &&
    line.value.has_suffix(b"\r") {
    line.value[:line.value.length() - 1]
  } else {
    line.value
  }
  out.write_string(prefix)
  out.write_string(@bytere.text(value))
  out.write_char('\n')
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
fn meaningful(edit : Edit, options : CompareOptions) -> Bool {
  match edit {
    Equal(_) => false
    Remove(line) | Add(line) =>
      !options.ignore_blank_lines || !blank_line(line, options)
  }
}

///|
fn normal(
  changes : Array[Edit],
  options~ : CompareOptions = compare_options(),
) -> Bytes {
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
    if options.ignore_blank_lines &&
      !removed.iter().any(line => !blank_line(line, options)) &&
      !added.iter().any(line => !blank_line(line, options)) {
      old_line += removed.length()
      new_line += added.length()
      continue
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
      record(output, "< ", line, options~)
    }
    if !removed.is_empty() && !added.is_empty() {
      output.write_string("---\n")
    }
    for line in added {
      record(output, "> ", line, options~)
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
  options~ : CompareOptions = compare_options(),
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
    if !changes[start:end].iter().any(edit => meaningful(edit, options)) {
      position = end
      continue
    }
    let old_start = old_positions[start]
    let new_start = new_positions[start]
    if context_format {
      output.write_string(
        "***************\n*** " +
        range(old_start, old_positions[end] - old_start, false) +
        " ****\n",
      )
      context_side(output, changes[start:end], true, options)
      output.write_string(
        "--- " +
        range(new_start, new_positions[end] - new_start, false) +
        " ----\n",
      )
      context_side(output, changes[start:end], false, options)
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
          Equal(line) => record(output, " ", line, options~)
          Remove(line) => record(output, "-", line, options~)
          Add(line) => record(output, "+", line, options~)
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
  options : CompareOptions,
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
        record(output, "  ", line, options~)
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
            Remove(line) => if old { record(output, prefix, line, options~) }
            Add(line) => if !old { record(output, prefix, line, options~) }
            _ => ()
          }
        }
      }
    }
  }
}
