///|
priv suberror PatchError {
  PatchError(String)
}

///|
priv suberror HunkMismatch {
  HunkMismatch(Int, Int)
}

///|
struct Line {
  value : String
  terminated : Bool
} derive(Eq, Debug)

///|
struct Change {
  kind : Char
  line : Line
}

///|
struct Hunk {
  old_start : Int
  old_count : Int
  new_start : Int
  new_count : Int
  changes : Array[Change]
}

///|
struct FilePatch {
  old_name : String
  new_name : String
  hunks : Array[Hunk]
}

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
fn range(text : String, sign : Char) -> (Int, Int) raise PatchError {
  if text.is_empty() || text[0].to_int() != sign.to_int() {
    raise PatchError("malformed hunk range")
  }
  let parts = text[1:].split(",").to_array()
  if parts.length() < 1 || parts.length() > 2 {
    raise PatchError("malformed hunk range")
  }
  let start = @string.parse_int(parts[0]) catch {
    _ => raise PatchError("malformed hunk range")
  }
  let count = if parts.length() == 2 {
    @string.parse_int(parts[1]) catch {
      _ => raise PatchError("malformed hunk range")
    }
  } else {
    1
  }
  if start < 0 || count < 0 || (start == 0 && count != 0) {
    raise PatchError("invalid hunk range")
  }
  (start, count)
}

///|
fn header_name(header : String) -> String raise {
  let label = header[4:].split("\t").to_array()[0].to_owned()
  if label.is_empty() {
    raise PatchError("empty file name")
  }
  if label.has_prefix("\"") {
    raise PatchError("quoted file names are not supported")
  }
  @utf8.decode(@bytere.bytes(label))
}

///|
fn parse_unified(data : Bytes) -> Array[FilePatch] raise {
  let input = lines(data)
  let files : Array[FilePatch] = []
  let mut i = 0
  while i < input.length() {
    let text = input[i].value
    if text.has_prefix("GIT binary patch") ||
      text.has_prefix("new file mode ") ||
      text.has_prefix("deleted file mode ") ||
      text.has_prefix("old mode ") ||
      text.has_prefix("new mode ") ||
      text.has_prefix("rename ") ||
      text.has_prefix("copy ") {
      raise PatchError("binary, rename and mode patches are not supported")
    }
    if !text.has_prefix("--- ") {
      i += 1
      continue
    }
    let old_name = header_name(text)
    i += 1
    if i >= input.length() || !input[i].value.has_prefix("+++ ") {
      raise PatchError("missing +++ file header")
    }
    let new_name = header_name(input[i].value)
    i += 1
    let hunks : Array[Hunk] = []
    while i < input.length() && input[i].value.has_prefix("@@ ") {
      let fields = input[i].value.split(" ").to_array()
      if fields.length() < 4 || fields[0] != "@@" || fields[3] != "@@" {
        raise PatchError("malformed hunk header")
      }
      let (old_start, old_count) = range(fields[1].to_owned(), '-')
      let (new_start, new_count) = range(fields[2].to_owned(), '+')
      let changes : Array[Change] = []
      let mut removed = 0
      let mut added = 0
      i += 1
      while i < input.length() {
        let line = input[i]
        if line.value == "\\ No newline at end of file" {
          if changes.is_empty() {
            raise PatchError("misplaced no-newline marker")
          }
          let last = changes[changes.length() - 1]
          if !last.line.terminated {
            raise PatchError("duplicate no-newline marker")
          }
          changes[changes.length() - 1] = {
            kind: last.kind,
            line: { value: last.line.value, terminated: false, },
          }
          i += 1
          continue
        }
        if removed == old_count && added == new_count {
          break
        }
        if line.value.is_empty() || !line.terminated {
          raise PatchError("incomplete hunk")
        }
        let kind = line.value[0].to_int().unsafe_to_char()
        if kind != ' ' && kind != '-' && kind != '+' {
          raise PatchError("invalid hunk line")
        }
        if kind != '+' {
          removed += 1
        }
        if kind != '-' {
          added += 1
        }
        if removed > old_count || added > new_count {
          raise PatchError("hunk length does not match header")
        }
        changes.push({
          kind,
          line: { value: line.value[1:].to_owned(), terminated: true, },
        })
        i += 1
      }
      if removed != old_count || added != new_count {
        raise PatchError("incomplete hunk")
      }
      hunks.push({ old_start, old_count, new_start, new_count, changes, })
    }
    if hunks.is_empty() {
      raise PatchError("file patch has no unified hunks")
    }
    files.push({ old_name, new_name, hunks, })
  }
  if files.is_empty() {
    raise PatchError("no unified patch found")
  }
  files
}

///|
fn context_range(
  text : String,
  prefix : String,
  suffix : String,
) -> (Int, Int) raise PatchError {
  if !text.has_prefix(prefix) || !text.has_suffix(suffix) {
    raise PatchError("malformed context range")
  }
  let value = text[prefix.length():text.length() - suffix.length()]
    .trim()
    .to_owned()
  let pieces = value.split(",").collect()
  if pieces.length() < 1 || pieces.length() > 2 {
    raise PatchError("malformed context range")
  }
  let start = @string.parse_int(pieces[0]) catch {
    _ => raise PatchError("malformed context range")
  }
  let end = if pieces.length() == 2 {
    @string.parse_int(pieces[1]) catch {
      _ => raise PatchError("malformed context range")
    }
  } else {
    start
  }
  if start < 0 || end < start {
    raise PatchError("invalid context range")
  }
  (start, if start == 0 && end == 0 { 0 } else { end - start + 1 })
}

///|
fn context_rows(
  input : Array[Line],
  start : Int,
  old : Bool,
) -> (Array[Change], Int) raise PatchError {
  let result : Array[Change] = []
  let mut i = start
  while i < input.length() {
    let line = input[i]
    if line.value == "\\ No newline at end of file" {
      if result.is_empty() {
        raise PatchError("misplaced no-newline marker")
      }
      let last = result[result.length() - 1]
      if !last.line.terminated {
        raise PatchError("duplicate no-newline marker")
      }
      result[result.length() - 1] = {
        kind: last.kind,
        line: { value: last.line.value, terminated: false, },
      }
      i += 1
      continue
    }
    if line.value.length() < 2 || line.value[1] != ' ' {
      break
    }
    let kind = line.value[0].to_int().unsafe_to_char()
    if kind != ' ' && kind != '!' && kind != (if old { '-' } else { '+' }) {
      break
    }
    if !line.terminated {
      raise PatchError("incomplete context line")
    }
    result.push({
      kind: if kind == ' ' {
        ' '
      } else if old {
        '-'
      } else {
        '+'
      },
      line: { value: line.value[2:].to_owned(), terminated: true, },
    })
    i += 1
  }
  (result, i)
}

///|
fn merge_context(
  old : Array[Change],
  newer : Array[Change],
) -> Array[Change] raise PatchError {
  let old = if old.is_empty() { newer.filter(v => v.kind == ' ') } else { old }
  let newer = if newer.is_empty() {
    old.filter(v => v.kind == ' ')
  } else {
    newer
  }
  let result : Array[Change] = []
  let mut i = 0
  let mut j = 0
  while i < old.length() || j < newer.length() {
    while i < old.length() && old[i].kind == '-' {
      result.push(old[i])
      i += 1
    }
    while j < newer.length() && newer[j].kind == '+' {
      result.push(newer[j])
      j += 1
    }
    if i == old.length() && j == newer.length() {
      break
    }
    if i == old.length() || j == newer.length() || old[i].line != newer[j].line {
      raise PatchError("context sections disagree")
    }
    result.push(old[i])
    i += 1
    j += 1
  }
  result
}

///|
fn parse_context(data : Bytes) -> Array[FilePatch] raise {
  let input = lines(data)
  let files : Array[FilePatch] = []
  let mut i = 0
  while i < input.length() {
    let text = input[i].value
    if text.has_prefix("GIT binary patch") ||
      text.has_prefix("new file mode ") ||
      text.has_prefix("deleted file mode ") ||
      text.has_prefix("old mode ") ||
      text.has_prefix("new mode ") ||
      text.has_prefix("rename ") ||
      text.has_prefix("copy ") {
      raise PatchError("binary, rename and mode patches are not supported")
    }
    if text.has_prefix("+++ ") {
      raise PatchError("mixed unified and context input is not supported")
    }
    if !input[i].value.has_prefix("*** ") {
      i += 1
      continue
    }
    let old_name = header_name(input[i].value)
    i += 1
    if i >= input.length() || !input[i].value.has_prefix("--- ") {
      raise PatchError("missing context file header")
    }
    let new_name = header_name(input[i].value)
    i += 1
    let hunks : Array[Hunk] = []
    while i < input.length() && input[i].value.has_prefix("***************") {
      i += 1
      if i >= input.length() {
        raise PatchError("incomplete context hunk")
      }
      let (old_start, old_count) = context_range(
        input[i].value,
        "*** ",
        " ****",
      )
      let (old, after_old) = context_rows(input, i + 1, true)
      i = after_old
      if i >= input.length() {
        raise PatchError("incomplete context hunk")
      }
      let (new_start, new_count) = context_range(
        input[i].value,
        "--- ",
        " ----",
      )
      let (newer, after_new) = context_rows(input, i + 1, false)
      i = after_new
      let changes = merge_context(old, newer)
      let removed = changes.filter(v => v.kind != '+').length()
      let added = changes.filter(v => v.kind != '-').length()
      if removed != old_count || added != new_count {
        raise PatchError("context hunk length does not match header")
      }
      hunks.push({ old_start, old_count, new_start, new_count, changes, })
    }
    if hunks.is_empty() {
      raise PatchError("file patch has no context hunks")
    }
    files.push({ old_name, new_name, hunks, })
  }
  if files.is_empty() {
    raise PatchError("no context patch found")
  }
  files
}

///|
fn parse_patch(data : Bytes) -> Array[FilePatch] raise {
  for line in lines(data) {
    if line.value.has_prefix("*** ") {
      return parse_context(data)
    }
    if line.value.has_prefix("--- ") {
      return parse_unified(data)
    }
  }
  raise PatchError("no unified or context patch found")
}

///|
fn apply_patch_bytes(
  data : Bytes,
  hunks : Array[Hunk],
  reverse : Bool,
) -> Bytes raise HunkMismatch {
  let input = lines(data)
  let output = StringBuilder()
  let mut cursor = 0
  for index, hunk in hunks {
    let start = if reverse { hunk.new_start } else { hunk.old_start }
    let count = if reverse { hunk.new_count } else { hunk.old_count }
    let position = if count == 0 { start } else { start - 1 }
    if position < cursor || position > input.length() {
      raise HunkMismatch(index + 1, start)
    }
    for line in input[cursor:position] {
      output.write_string(line.value)
      if line.terminated {
        output.write_char('\n')
      }
    }
    cursor = position
    for change in hunk.changes {
      let kind = if reverse {
        match change.kind {
          '+' => '-'
          '-' => '+'
          _ => ' '
        }
      } else {
        change.kind
      }
      if kind != '+' {
        if cursor >= input.length() || input[cursor] != change.line {
          raise HunkMismatch(index + 1, start)
        }
        cursor += 1
      }
      if kind != '-' {
        output.write_string(change.line.value)
        if change.line.terminated {
          output.write_char('\n')
        }
      }
    }
  }
  for line in input[cursor:] {
    output.write_string(line.value)
    if line.terminated {
      output.write_char('\n')
    }
  }
  @bytere.bytes(output.to_string())
}
