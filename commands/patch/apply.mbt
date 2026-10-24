///|
priv enum HunkResult {
  Applied(position~ : Int32, offset~ : Int32, fuzz~ : Int32)
  Rejected(position~ : Int32, output_delta~ : Int32)
}

///|
priv struct AppliedPatch {
  data : Bytes
  results : Array[HunkResult]
}

///|
fn reversed_kind(kind : Char, reverse : Bool) -> Char {
  if reverse {
    match kind {
      '+' => '-'
      '-' => '+'
      _ => kind
    }
  } else {
    kind
  }
}

///|
fn write_line(output : StringBuilder, line : Line) -> Unit {
  output.write_string(line.value)
  if line.terminated {
    output.write_char('\n')
  }
}

///|
fn hunk_context(hunk : Hunk) -> (Int32, Int32) {
  let mut prefix = 0
  while prefix < hunk.changes.length() && hunk.changes[prefix].kind == ' ' {
    prefix += 1
  }
  let mut suffix = 0
  while suffix < hunk.changes.length() &&
        hunk.changes[hunk.changes.length() - suffix - 1].kind == ' ' {
    suffix += 1
  }
  (prefix, suffix)
}

///|
fn hunk_old_lines(hunk : Hunk, reverse : Bool) -> Array[Line] {
  hunk.changes
  .filter(change => reversed_kind(change.kind, reverse) != '+')
  .map(change => change.line)
}

///|
fn matching_at(
  input : Array[Line],
  old : Array[Line],
  position : Int32,
  prefix : Int32,
  suffix : Int32,
) -> Bool {
  for index in prefix..<(old.length() - suffix) {
    let target = position + index
    if target < 0 || target >= input.length() || input[target] != old[index] {
      return false
    }
  }
  true
}

///|
fn locate_hunk(
  input : Array[Line],
  old : Array[Line],
  start : Int32,
  guessed : Int64,
  frozen : Int32,
  prefix : Int32,
  suffix : Int32,
  fuzz : Int32,
) -> Int32? {
  if old.is_empty() {
    return if guessed >= frozen.to_int64() && guessed <= 2147483647L {
      Some(guessed.to_int())
    } else {
      None
    }
  }
  let context = prefix.max(suffix)
  let prefix_fuzz = fuzz + prefix - context
  let suffix_fuzz = fuzz + suffix - context
  if prefix_fuzz < 0 && start <= 1 {
    if suffix_fuzz < 0 && (old.length() != input.length() || prefix < frozen) {
      return None
    }
    return if frozen <= prefix &&
      matching_at(input, old, 0, 0, suffix_fuzz.max(0)) {
      Some(0)
    } else {
      None
    }
  }
  if suffix_fuzz < 0 {
    let position = input.length() - old.length()
    return if position >= frozen &&
      matching_at(input, old, position, prefix_fuzz.max(0), 0) {
      Some(position)
    } else {
      None
    }
  }
  let low = frozen.to_int64()
  let high = (input.length() - old.length() + suffix_fuzz).to_int64()
  if low > high {
    return None
  }
  let mut distance = if guessed < low {
    low - guessed
  } else if guessed > high {
    guessed - high
  } else {
    0L
  }
  let maximum = (guessed - low).max(high - guessed)
  while distance <= maximum {
    // GNU chooses a later occurrence before an equally distant earlier one.
    let after = guessed + distance
    if after >= low &&
      after <= high &&
      matching_at(input, old, after.to_int(), prefix_fuzz.max(0), suffix_fuzz) {
      return Some(after.to_int())
    }
    let before = guessed - distance
    if distance != 0L &&
      before >= low &&
      before <= high &&
      matching_at(input, old, before.to_int(), prefix_fuzz.max(0), suffix_fuzz) {
      return Some(before.to_int())
    }
    distance += 1
  }
  None
}

///|
fn apply_hunks(
  data : Bytes,
  hunks : Array[Hunk],
  reverse : Bool,
  max_fuzz : Int32,
) -> AppliedPatch {
  let input = lines(data)
  let output = StringBuilder()
  let results : Array[HunkResult] = []
  let mut cursor = 0
  let mut offset = 0
  let mut output_delta = 0
  for hunk in hunks {
    let start = if reverse { hunk.new_start } else { hunk.old_start }
    let count = if reverse { hunk.new_count } else { hunk.old_count }
    let new_count = if reverse { hunk.old_count } else { hunk.new_count }
    let base = if count == 0 { start } else { start - 1 }
    let old = hunk_old_lines(hunk, reverse)
    let (prefix, suffix) = hunk_context(hunk)
    let mut selected : (Int32, Int32)? = None
    for fuzz in 0..<=max_fuzz.min(prefix.max(suffix)) {
      let guessed = base.to_int64() + offset.to_int64()
      if locate_hunk(input, old, start, guessed, cursor, prefix, suffix, fuzz)
        is Some(position) {
        selected = Some((position, fuzz))
        break
      }
    }
    guard selected is Some((position, fuzz)) else {
      results.push(Rejected(position=base + 1 + output_delta, output_delta~))
      continue
    }
    offset = position - base
    results.push(Applied(position=position + 1 + output_delta, offset~, fuzz~))
    let mut old_index = 0
    for change in hunk.changes {
      let kind = reversed_kind(change.kind, reverse)
      if kind == ' ' {
        old_index += 1
        continue
      }
      let until = position + old_index
      for line in input[cursor.min(input.length()):until.min(input.length())] {
        write_line(output, line)
      }
      cursor = until
      if kind == '-' {
        cursor += 1
        old_index += 1
      } else {
        write_line(output, change.line)
      }
    }
    output_delta += new_count - count
  }
  for line in input[cursor.min(input.length()):] {
    write_line(output, line)
  }
  { data: @bytere.bytes(output.to_string()), results, }
}

///|
fn batch_reverse(
  data : Bytes,
  hunk : Hunk,
  reverse : Bool,
  max_fuzz : Int32,
) -> Bool {
  let input = lines(data)
  let (prefix, suffix) = hunk_context(hunk)
  let forward = hunk_old_lines(hunk, reverse)
  let backward = hunk_old_lines(hunk, !reverse)
  let start = if reverse { hunk.new_start } else { hunk.old_start }
  let other_start = if reverse { hunk.old_start } else { hunk.new_start }
  let position = if forward.is_empty() { start } else { start - 1 }
  let other_position = if backward.is_empty() {
    other_start
  } else {
    other_start - 1
  }
  for fuzz in 0..<=max_fuzz.min(prefix.max(suffix)) {
    if locate_hunk(
        input,
        forward,
        start,
        position.to_int64(),
        0,
        prefix,
        suffix,
        fuzz,
      )
      is Some(_) {
      return reverse
    }
    if locate_hunk(
        input,
        backward,
        other_start,
        other_position.to_int64(),
        0,
        prefix,
        suffix,
        fuzz,
      )
      is Some(_) {
      return !reverse
    }
  }
  reverse
}

///|
fn reject_line(output : StringBuilder, prefix : String, line : Line) -> Unit {
  output.write_string(prefix)
  output.write_string(line.value)
  output.write_char('\n')
  if !line.terminated {
    output.write_string("\\ No newline at end of file\n")
  }
}

///|
fn unified_range(start : Int32, count : Int32) -> String {
  if count == 1 {
    start.to_string()
  } else {
    "\{start},\{count}"
  }
}

///|
fn context_range_text(start : Int32, count : Int32) -> String {
  if count == 0 {
    "0"
  } else if count == 1 {
    start.to_string()
  } else {
    "\{start},\{start + count - 1}"
  }
}

///|
fn reject_bytes(
  patch : FilePatch,
  results : Array[HunkResult],
  reverse : Bool,
) -> Bytes {
  let output = StringBuilder()
  let mut header = false
  for index, result in results {
    guard result is Rejected(output_delta~, ..) else { continue }
    let hunk = patch.hunks[index]
    let old_header = if reverse { patch.new_header } else { patch.old_header }
    let new_header = if reverse { patch.old_header } else { patch.new_header }
    let old_start = (if reverse { hunk.new_start } else { hunk.old_start }) +
      output_delta
    let new_start = (if reverse { hunk.old_start } else { hunk.new_start }) +
      output_delta
    let old_count = if reverse { hunk.new_count } else { hunk.old_count }
    let new_count = if reverse { hunk.old_count } else { hunk.new_count }
    if !header {
      output.write_string(
        (if patch.unified { "--- " } else { "*** " }) + old_header + "\n",
      )
      output.write_string(
        (if patch.unified { "+++ " } else { "--- " }) + new_header + "\n",
      )
      header = true
    }
    let old_rows : Array[(String, Line)] = []
    let new_rows : Array[(String, Line)] = []
    let mut cursor = 0
    if patch.unified {
      output.write_string(
        "@@ -" +
        unified_range(old_start, old_count) +
        " +" +
        unified_range(new_start, new_count) +
        " @@" +
        hunk.section +
        "\n",
      )
    }
    while cursor < hunk.changes.length() {
      let change = hunk.changes[cursor]
      if change.kind == ' ' {
        if patch.unified {
          reject_line(output, " ", change.line)
        } else {
          old_rows.push(("  ", change.line))
          new_rows.push(("  ", change.line))
        }
        cursor += 1
        continue
      }
      let mut end = cursor
      while end < hunk.changes.length() && hunk.changes[end].kind != ' ' {
        end += 1
      }
      let group = hunk.changes[cursor:end]
      let old = group.filter(change => {
        reversed_kind(change.kind, reverse) == '-'
      })
      let newer = group.filter(change => {
        reversed_kind(change.kind, reverse) == '+'
      })
      for change in old {
        if patch.unified {
          reject_line(output, "-", change.line)
        } else {
          old_rows.push(
            (if newer.is_empty() { "- " } else { "! " }, change.line),
          )
        }
      }
      for change in newer {
        if patch.unified {
          reject_line(output, "+", change.line)
        } else {
          new_rows.push((if old.is_empty() { "+ " } else { "! " }, change.line))
        }
      }
      cursor = end
    }
    if !patch.unified {
      output.write_string(
        "***************" +
        hunk.section +
        "\n*** " +
        context_range_text(old_start, old_count) +
        " ****\n",
      )
      for (prefix, line) in old_rows {
        reject_line(output, prefix, line)
      }
      output.write_string(
        "--- " + context_range_text(new_start, new_count) + " ----\n",
      )
      for (prefix, line) in new_rows {
        reject_line(output, prefix, line)
      }
    }
  }
  @bytere.bytes(output.to_string())
}
