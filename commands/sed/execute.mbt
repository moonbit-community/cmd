///|
struct Runtime {
  mut previous : PreparedPattern?
  mut missing_newline : Bool
  output : @stream.BlockWriter
}

///|
fn PatternRef::resolve(
  self : PatternRef,
  runtime : Runtime,
) -> PreparedPattern raise {
  match self {
    Explicit(pattern) => {
      runtime.previous = Some(pattern)
      pattern
    }
    Previous =>
      match runtime.previous {
        Some(pattern) => pattern
        None => fail("no previous regular expression")
      }
  }
}

///|
async fn Address::matches(
  self : Address,
  input : Input,
  space : Space,
  runtime : Runtime,
) -> Bool {
  match self {
    Number(n) => n == input.number
    Last => !input.has_next()
    Search(re) => re.resolve(runtime).matches(space)
  }
}

///|
async fn Command::selected(
  self : Command,
  input : Input,
  space : Space,
  runtime : Runtime,
) -> Bool {
  let mut selected = false
  let line = input.number
  if self.last is Some(end) {
    let was_inside = self.inside
    let starts = if self.inside {
      false
    } else if self.first is Some(Number(n)) {
      !self.closed && line >= n
    } else {
      self.first.unwrap().matches(input, space, runtime)
    }
    if !self.inside && starts {
      self.inside = true
    }
    selected = self.inside
    if self.inside {
      let ended = match end {
        Number(n) => line >= n
        Last => !input.has_next()
        Search(_) => was_inside && end.matches(input, space, runtime)
      }
      if ended {
        self.inside = false
        self.closed = true
        if end is Number(n) && line > n {
          selected = !was_inside &&
            self.first.unwrap().matches(input, space, runtime)
        }
      }
    }
  } else {
    selected = self.first is None ||
      self.first.unwrap().matches(input, space, runtime)
  }
  if self.invert {
    !selected
  } else {
    selected
  }
}

///|
fn expand(replacement : String, hit : @bytere.Hit) -> String raise {
  let result = StringBuilder()
  let mut i = 0
  while i < replacement.length() {
    let c = replacement[i]
    if c == '&' {
      result.write_string(hit.groups[0].unwrap_or(""))
    } else if c == '\\' && i + 1 < replacement.length() {
      i += 1
      let e = replacement[i]
      if e >= '1' && e <= '9' {
        let index = e.to_int() - 48
        guard index < hit.groups.length() else {
          fail("invalid replacement backreference")
        }
        result.write_string(hit.groups[index].unwrap_or(""))
      } else {
        result.write_char(
          if e == 'n' {
            '\n'
          } else if e == 't' {
            '\t'
          } else {
            e.to_int().unsafe_to_char()
          },
        )
      }
    } else {
      result.write_char(c.to_int().unsafe_to_char())
    }
    i += 1
  }
  result.to_string()
}

///|
fn substitute(
  re : @bytere.Pattern,
  text : String,
  replacement : String,
  global : Bool,
  occurrence : Int32,
) -> (String, Bool) raise {
  let result = StringBuilder()
  let mut search = 0
  let mut copied = 0
  let mut count = 0
  let mut changed = false
  let mut nonempty_end = -1
  while search <= text.length() {
    guard re.find(text, start=search) is Some(hit) else { break }
    if hit.start == hit.end && hit.start == nonempty_end {
      search = hit.end + 1
      continue
    }
    count += 1
    let replace = if occurrence == 0 {
      global || count == 1
    } else {
      count == occurrence || (global && count > occurrence)
    }
    if replace {
      result.write_string(text[copied:hit.start].to_owned())
      result.write_string(expand(replacement, hit))
      copied = hit.end
      changed = true
      if !global {
        break
      }
    }
    nonempty_end = if hit.end > hit.start { hit.end } else { -1 }
    search = if hit.end == hit.start { hit.end + 1 } else { hit.end }
  }
  if !changed {
    return (text, false)
  }
  result.write_string(text[copied:].to_owned())
  (result.to_string(), changed)
}

///|
// Strategy: sed-record-output

///|
fn output_record(
  text : String,
  terminated : Bool,
  missing_newline : Bool,
) -> Bytes {
  let bytes = @bytere.bytes(text)
  output_bytes_record(bytes[:], terminated, missing_newline)
}

///|
fn output_bytes_record(
  bytes : BytesView,
  terminated : Bool,
  missing_newline : Bool,
) -> Bytes {
  let prefix = if missing_newline { 1 } else { 0 }
  let suffix = if terminated { 1 } else { 0 }
  if prefix + suffix == 0 {
    return bytes.to_owned()
  }
  output_record_buffer(bytes, terminated, missing_newline).unsafe_reinterpret_as_bytes()
}

///|
fn output_record_buffer(
  bytes : BytesView,
  terminated : Bool,
  missing_newline : Bool,
) -> FixedArray[Byte] {
  let prefix = if missing_newline { 1 } else { 0 }
  let suffix = if terminated { 1 } else { 0 }
  let output = FixedArray::make(prefix + bytes.length() + suffix, b'\n')
  output.blit_from_bytesview(prefix, bytes)
  output
}

///|
async fn Runtime::emit(
  self : Runtime,
  text : String,
  terminated : Bool,
) -> Unit {
  self.output.write_bytes(output_record(text, terminated, self.missing_newline))
  self.missing_newline = !terminated
}

///|
fn Runtime::buffer_space(
  self : Runtime,
  space : Space,
) -> FixedArray[Byte]? raise {
  let bytes = match space.data {
    Some(data) => data
    None => @bytere.bytes(space.text())[:]
  }
  let output = output_record_buffer(
    bytes,
    space.terminated,
    self.missing_newline,
  )
  if self.output.try_write_slice(output, 0, output.length()) {
    self.missing_newline = !space.terminated
    None
  } else {
    Some(output)
  }
}

///|
async fn Runtime::emit_space(self : Runtime, space : Space) -> Unit {
  if self.buffer_space(space) is Some(output) {
    self.output.write_slice(output, 0, output.length())
    self.missing_newline = !space.terminated
  }
}

///|
struct Input {
  paths : Array[String]
  mut index : Int32
  mut path : String
  mut file : @fs.File?
  mut reader : &@io.Reader?
  mut buffer : Bytes
  mut position : Int32
  mut number : Int32
  mut status : Int32
  output : @stream.BlockWriter
}

///|
fn Input::close(self : Input) -> Unit {
  if self.file is Some(file) {
    file.close()
  }
  self.file = None
  self.reader = None
  self.buffer = b""
  self.position = 0
}

///|
async fn Input::open_next(self : Input) -> Bool {
  self.output.flush()
  while self.index < self.paths.length() {
    self.path = self.paths[self.index]
    self.index += 1
    if self.path == "-" {
      self.reader = Some((@stdio.stdin : &@io.Reader))
      return true
    }
    try {
      let file = @fs.open(self.path, mode=ReadOnly)
      self.file = Some(file)
      self.reader = Some((file : &@io.Reader))
      return true
    } catch {
      err => {
        @stdio.stderr.write("sed: \{self.path}: \{err}\n")
        self.status = 2
      }
    }
  }
  false
}

///|
async fn Input::fill(self : Input) -> Bool {
  if self.position < self.buffer.length() {
    return true
  }
  guard self.reader is Some(reader) else { return false }
  // Commit earlier output before an external read can block or report an error.
  // Already buffered input never introduces a new I/O boundary.
  self.output.flush()
  let chunk = reader.read_some(max_len=@stream.chunk_size) catch {
    err => {
      @stdio.stderr.write("sed: \{self.path}: \{err}\n")
      self.status = 2
      None
    }
  }
  match chunk {
    Some(bytes) => {
      self.buffer = bytes
      self.position = 0
      true
    }
    None => {
      self.close()
      false
    }
  }
}

///|
// EOF lookahead retains at most one bounded chunk, rather than consuming a
// complete next record before n/N can flush their pending append output.
async fn Input::has_next(self : Input) -> Bool {
  for ;; {
    if self.fill() {
      return true
    }
    if !self.open_next() {
      return false
    }
  }
}

///|
fn Input::next_cached(self : Input) -> @stream.RecordView? {
  let first = self.position
  guard first < self.buffer.length() &&
    self.buffer[first:].find(b"\n") is Some(length) else {
    return None
  }
  self.position = first + length + 1
  self.number += 1
  Some({ data: self.buffer[first:first + length], terminated: true, })
}

///|
async fn Input::next(self : Input) -> @stream.RecordView? {
  guard self.has_next() else { return None }
  if self.next_cached() is Some(record) {
    return Some(record)
  }
  let first = self.position
  // Complete records borrow the immutable chunk. A spanning record uses one buffer,
  // so fragmented readers do not retain one allocation per input fragment.
  let pending = @buffer.Buffer(size_hint=self.buffer.length() - first)
  pending.write_bytes(self.buffer[first:])
  self.position = self.buffer.length()
  let mut terminated = false
  for ;; {
    guard self.fill() else { break }
    if self.buffer[:].find(b"\n") is Some(length) {
      pending.write_bytes(self.buffer[:length])
      self.position = length + 1
      terminated = true
      break
    }
    pending.write_bytes(self.buffer[:])
    self.position = self.buffer.length()
  }
  self.number += 1
  Some({ data: pending.to_bytes()[:], terminated, })
}

///|
async fn Runtime::finish_line(self : Runtime) -> Unit {
  if self.missing_newline {
    self.output.write_bytes(b"\n")
    self.missing_newline = false
  }
}

///|
async fn Runtime::text(self : Runtime, text : String) -> Unit {
  if text != "" {
    self.finish_line()
    self.output.write_bytes(@bytere.bytes(text))
  }
}

///|
async fn flush_append(
  queue : Array[String],
  runtime : Runtime,
  force~ : Bool = false,
) -> Unit {
  if queue.is_empty() && !force {
    return
  }
  runtime.finish_line()
  for text in queue {
    runtime.output.write_bytes(@bytere.bytes(text))
  }
  queue.clear()
}

///|
// Deferred output remains cancellable if the downstream writer stalls.
#warnings("-cancellable_defer")
async fn execute(
  commands : Array[Command],
  input : Input,
  quiet : Bool,
  runtime : Runtime,
) -> Unit {
  // A pending write failure precedes a later script error. BlockWriter
  // consumes failed writes, so this cannot replay a partially sent prefix.
  errdefer runtime.output.flush()
  execute_cycles(commands, input, quiet, runtime)
  runtime.output.flush()
}

///|
async fn execute_cycles(
  commands : Array[Command],
  input : Input,
  quiet : Bool,
  runtime : Runtime,
) -> Unit {
  let mut hold = Space::from_text("", true)
  let queue : Array[String] = []
  for ;; {
    if !queue.is_empty() {
      flush_append(queue, runtime)
    }
    let line = match input.next_cached() {
      Some(line) => line
      None =>
        match input.next() {
          Some(line) => line
          None => break
        }
    }
    let mut pattern = Space::from_bytes(line.data, line.terminated)
    let mut replaced = false
    let mut pc = 0
    let mut print_cycle = true
    while pc < commands.length() {
      let command = commands[pc]
      let selected = if command.first is None && command.last is None {
        !command.invert
      } else {
        command.selected(input, pattern, runtime)
      }
      if !selected {
        pc = match command.action {
          Group(target) => target
          _ => pc + 1
        }
        continue
      }
      match command.action {
        Label | EndGroup | Group(_) => ()
        Jump(target) => {
          pc = target
          continue
        }
        TestJump(target, positive) => {
          let jump = replaced == positive
          if replaced {
            replaced = false
          }
          if jump {
            pc = target
            continue
          }
        }
        Print => runtime.emit_space(pattern)
        PrintFirst =>
          match pattern.text().find("\n") {
            Some(end) => runtime.emit(pattern.text()[:end].to_owned(), true)
            None => runtime.emit_space(pattern)
          }
        Number => runtime.emit(input.number.to_string(), true)
        Delete => {
          print_cycle = false
          break
        }
        DeleteFirst =>
          match pattern.text().find("\n") {
            Some(end) => {
              pattern = Space::from_text(
                pattern.text()[end + 1:].to_owned(),
                pattern.terminated,
              )
              pc = 0
              continue
            }
            None => {
              print_cycle = false
              break
            }
          }
        Quit => {
          if !quiet {
            runtime.emit_space(pattern)
          }
          flush_append(queue, runtime, force=true)
          return
        }
        HoldCopy => hold = pattern
        HoldAppend => hold = hold.append(pattern)
        Get => pattern = hold
        GetAppend => pattern = pattern.append(hold)
        Exchange => {
          let previous = pattern
          pattern = hold
          hold = previous
        }
        Append(text) => queue.push(text)
        Insert(text) => runtime.text(text)
        Change(text) => {
          if !command.inside {
            runtime.text(text)
          }
          print_cycle = false
          break
        }
        Next | Join => {
          let join = command.action is Join
          if !join && !quiet {
            runtime.emit_space(pattern)
          }
          if !input.has_next() {
            if join && !quiet {
              runtime.emit_space(pattern)
            }
            print_cycle = false
            break
          }
          flush_append(queue, runtime)
          guard input.next() is Some(next) else {
            print_cycle = false
            break
          }
          let space = Space::from_bytes(next.data, next.terminated)
          pattern = if join { pattern.append(space) } else { space }
          replaced = false
        }
        Substitute(reference, replacement, global, occurrence, print) => {
          let prepared = reference.resolve(runtime)
          let re = prepared.pattern
          let mut r = 0
          while r < replacement.length() {
            if replacement[r] == '\\' && r + 1 < replacement.length() {
              r += 1
              if replacement[r] >= '1' &&
                replacement[r] <= '9' &&
                replacement[r].to_int() - 48 > re.group_count() {
                fail("invalid replacement backreference")
              }
            }
            r += 1
          }
          // Resolve executed-pattern history and validate replacement references
          // before a byte rejection can bypass text conversion or matching.
          if !prepared.rejects(pattern) {
            let (value, changed) = substitute(
              re,
              pattern.text(),
              replacement,
              global,
              occurrence,
            )
            if changed {
              pattern = Space::from_text(value, pattern.terminated)
              replaced = true
              if print {
                runtime.emit_space(pattern)
              }
            }
          }
        }
      }
      pc += 1
    }
    if print_cycle && !quiet {
      if runtime.buffer_space(pattern) is Some(output) {
        runtime.output.write_slice(output, 0, output.length())
        runtime.missing_newline = !pattern.terminated
      }
    }
  }
}
