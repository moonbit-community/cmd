///|
struct Runtime {
  mut previous : @bytere.Pattern?
  mut missing_newline : Bool
}

///|
fn PatternRef::resolve(
  self : PatternRef,
  runtime : Runtime,
) -> @bytere.Pattern raise {
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
  text : String,
  runtime : Runtime,
) -> Bool {
  match self {
    Number(n) => n == input.number
    Last => !input.has_next()
    Search(re) => re.resolve(runtime).find_span(text) is Some(_)
  }
}

///|
async fn Command::selected(
  self : Command,
  input : Input,
  text : String,
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
      self.first.unwrap().matches(input, text, runtime)
    }
    if !self.inside && starts {
      self.inside = true
    }
    selected = self.inside
    if self.inside {
      let ended = match end {
        Number(n) => line >= n
        Last => !input.has_next()
        Search(_) => was_inside && end.matches(input, text, runtime)
      }
      if ended {
        self.inside = false
        self.closed = true
        if end is Number(n) && line > n {
          selected = !was_inside &&
            self.first.unwrap().matches(input, text, runtime)
        }
      }
    }
  } else {
    selected = self.first is None ||
      self.first.unwrap().matches(input, text, runtime)
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
  result.write_string(text[copied:].to_owned())
  (result.to_string(), changed)
}

///|
async fn Runtime::emit(
  self : Runtime,
  text : String,
  terminated : Bool,
) -> Unit {
  if self.missing_newline {
    @stdio.stdout.write(b"\n")
  }
  @stdio.stdout.write(@bytere.bytes(text))
  if terminated {
    @stdio.stdout.write(b"\n")
  }
  self.missing_newline = !terminated
}

///|
struct Space {
  text : String
  terminated : Bool
}

///|
fn Space::append(self : Space, other : Space) -> Space {
  { text: self.text + "\n" + other.text, terminated: other.terminated, }
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
async fn Input::next(self : Input) -> @stream.Line? {
  guard self.has_next() else { return None }
  let bytes : Array[Byte] = []
  for ;; {
    while self.position < self.buffer.length() {
      let byte = self.buffer[self.position]
      self.position += 1
      if byte == b'\n' {
        self.number += 1
        return Some({ data: Bytes::from_array(bytes), terminated: true, })
      }
      bytes.push(byte)
    }
    if !self.fill() {
      self.number += 1
      return Some({ data: Bytes::from_array(bytes), terminated: false, })
    }
  }
}

///|
async fn Runtime::finish_line(self : Runtime) -> Unit {
  if self.missing_newline {
    @stdio.stdout.write(b"\n")
    self.missing_newline = false
  }
}

///|
async fn Runtime::text(self : Runtime, text : String) -> Unit {
  if text != "" {
    self.finish_line()
    @stdio.stdout.write(@bytere.bytes(text))
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
    @stdio.stdout.write(@bytere.bytes(text))
  }
  queue.clear()
}

///|
async fn execute(
  commands : Array[Command],
  input : Input,
  quiet : Bool,
  runtime : Runtime,
) -> Unit {
  let mut hold = Space::{ text: "", terminated: true, }
  let queue : Array[String] = []
  for ;; {
    flush_append(queue, runtime)
    guard input.next() is Some(line) else { break }
    let mut pattern = Space::{
      text: @bytere.text(line.data),
      terminated: line.terminated,
    }
    let mut replaced = false
    let mut pc = 0
    let mut print_cycle = true
    while pc < commands.length() {
      let command = commands[pc]
      let selected = command.selected(input, pattern.text, runtime)
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
        Print => runtime.emit(pattern.text, pattern.terminated)
        PrintFirst =>
          match pattern.text.find("\n") {
            Some(end) => runtime.emit(pattern.text[:end].to_owned(), true)
            None => runtime.emit(pattern.text, pattern.terminated)
          }
        Number => runtime.emit(input.number.to_string(), true)
        Delete => {
          print_cycle = false
          break
        }
        DeleteFirst =>
          match pattern.text.find("\n") {
            Some(end) => {
              pattern = { ..pattern, text: pattern.text[end + 1:].to_owned(), }
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
            runtime.emit(pattern.text, pattern.terminated)
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
            runtime.emit(pattern.text, pattern.terminated)
          }
          if !input.has_next() {
            if join && !quiet {
              runtime.emit(pattern.text, pattern.terminated)
            }
            print_cycle = false
            break
          }
          flush_append(queue, runtime)
          guard input.next() is Some(next) else {
            print_cycle = false
            break
          }
          let space = Space::{
            text: @bytere.text(next.data),
            terminated: next.terminated,
          }
          pattern = if join { pattern.append(space) } else { space }
          replaced = false
        }
        Substitute(reference, replacement, global, occurrence, print) => {
          let re = reference.resolve(runtime)
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
          let (value, changed) = substitute(
            re,
            pattern.text,
            replacement,
            global,
            occurrence,
          )
          pattern = { ..pattern, text: value, }
          replaced = replaced || changed
          if print && changed {
            runtime.emit(pattern.text, pattern.terminated)
          }
        }
      }
      pc += 1
    }
    if print_cycle && !quiet {
      runtime.emit(pattern.text, pattern.terminated)
    }
  }
}
