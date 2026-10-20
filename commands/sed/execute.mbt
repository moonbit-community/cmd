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
fn Address::matches(
  self : Address,
  line : Int32,
  last : Bool,
  text : String,
  runtime : Runtime,
) -> Bool raise {
  match self {
    Number(n) => n == line
    Last => last
    Search(re) => re.resolve(runtime).find(text) is Some(_)
  }
}

///|
fn Command::selected(
  self : Command,
  line : Int32,
  last : Bool,
  text : String,
  runtime : Runtime,
) -> Bool raise {
  let mut selected = false
  if self.last is Some(end) {
    let was_inside = self.inside
    if !self.inside && self.first.unwrap().matches(line, last, text, runtime) {
      self.inside = true
    }
    selected = self.inside
    if self.inside {
      let ended = match end {
        Number(n) => line >= n
        Last => last
        Search(_) => was_inside && end.matches(line, last, text, runtime)
      }
      if ended {
        self.inside = false
      }
    }
  } else {
    selected = self.first is None ||
      self.first.unwrap().matches(line, last, text, runtime)
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
  self.missing_newline = !terminated && text != "" && !text.has_suffix("\n")
}

///|
async fn execute_line(
  commands : Array[Command],
  line : @stream.Line,
  number : Int32,
  last : Bool,
  quiet : Bool,
  runtime : Runtime,
) -> Bool {
  let mut text = @bytere.text(line.data)
  for command in commands {
    if !command.selected(number, last, text, runtime) {
      continue
    }
    match command.action {
      Print => runtime.emit(text, line.terminated)
      Number => runtime.emit(number.to_string(), true)
      Delete => return false
      Quit => {
        if !quiet {
          runtime.emit(text, line.terminated)
        }
        return true
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
          re, text, replacement, global, occurrence,
        )
        text = value
        if print && changed {
          runtime.emit(text, line.terminated)
        }
      }
    }
  }
  if !quiet {
    runtime.emit(text, line.terminated)
  }
  false
}
