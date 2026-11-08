///|
fn serial_child_flags(value : String) -> String raise MakeError {
  let words = makeflag_words(value)
  let arguments = inherited_make_arguments(words, include_assignments=false)
  let flags : Array[String] = []
  let assignments : Array[String] = []
  for argument in arguments {
    if !argument.has_prefix("-j") && !argument.has_prefix("--jobs") {
      flags.push(argument)
    }
  }
  for (name, operator, value) in inherited_make_assignments(words) {
    assignments.push(name + operator + value)
  }
  flags.push("-j1")
  if !assignments.is_empty() {
    flags.push("--")
    flags.append(assignments)
  }
  flags.map(escape_makeflag).join(" ")
}

///|
fn apply_makefile_flags(
  settings : Settings,
  arguments : Array[String],
) -> Settings raise MakeError {
  let mut jobs = settings.jobs
  let mut silent = settings.silent
  let mut dry_run = settings.dry_run
  let mut always_make = settings.always_make
  let mut keep_going = settings.keep_going
  for argument in arguments {
    match argument {
      "-s" | "--silent" => silent = true
      "-n" | "--just-print" => dry_run = true
      "-B" | "--always-make" => always_make = true
      "-k" | "--keep-going" => keep_going = true
      "-j" | "--jobs" => jobs = 0
      value if value.has_prefix("-j") || value.has_prefix("--jobs=") => {
        let count = value[if value.has_prefix("--") { 7 } else { 2 }:].to_owned()
        if !positive_job_count(count) {
          raise MakeError("MAKEFLAGS jobs requires a positive integer")
        }
        jobs = @string.parse_int(count, base=10) catch {
          _ => raise MakeError("MAKEFLAGS jobs requires a positive integer")
        }
      }
      value if parse_assignment(value) is Some(_) => ()
      _ => raise MakeError("unsupported MAKEFLAGS option '\{argument}'")
    }
  }
  { ..settings, jobs, silent, dry_run, always_make, keep_going, }
}

///|
priv struct Jobserver {
  reader : &@io.Reader
  writer : &@io.Writer
  close_handles : () -> Unit
  implicit : @semaphore.Semaphore
  acquiring : @async.Mutex
}

///|
async fn Jobserver::open(authentication : String) -> Jobserver {
  if !authentication.has_prefix("fifo:") {
    raise MakeError(
      "jobserver descriptor pipes and named semaphores require public descriptor-import or semaphore APIs; use FIFO authentication",
    )
  }
  let path = authentication[5:].to_owned()
  if path == "" {
    raise MakeError("jobserver FIFO path is empty")
  }
  if @async.platform is Windows {
    raise MakeError("FIFO jobserver inheritance is unavailable on Windows")
  }
  if @fs.kind(path) != Pipe {
    raise MakeError("jobserver authentication does not name a FIFO")
  }
  let reader = @fs.open(path, mode=ReadOnly, create_mode=OpenExisting)
  errdefer reader.close()
  if reader.kind() != Pipe {
    raise MakeError("jobserver FIFO changed while opening")
  }
  let writer = @fs.open(path, mode=WriteOnly, create_mode=OpenExisting)
  errdefer writer.close()
  if writer.kind() != Pipe {
    raise MakeError("jobserver FIFO changed while opening")
  }
  {
    reader,
    writer,
    close_handles: () => {
      reader.close()
      writer.close()
    },
    implicit: @semaphore.Semaphore(1),
    acquiring: @async.Mutex(),
  }
}

///|
fn Jobserver::close(self : Jobserver) -> Unit {
  (self.close_handles)()
}

///|
async fn[T] Jobserver::with_slot(self : Jobserver, action : async () -> T) -> T {
  // Only one read can wait on this handle. The implicit slot is raced against
  // the FIFO so a child finishing can unblock work even when no token arrives.
  self.acquiring.acquire()
  let mut locked = true
  defer (if locked { self.acquiring.release() })
  let mut implicit_owned = false
  let mut token : Bytes? = None
  defer @async.protect_from_cancel(() => {
    if implicit_owned {
      self.implicit.release()
    }
    if token is Some(value) {
      token = None
      self.writer.write(value)
    }
  })
  @async.any([
    () => {
      self.implicit.acquire()
      implicit_owned = true
    },
    () => {
      let byte = FixedArray::make(1, b'\x00')
      if self.reader.read(byte, max_len=1) != 1 {
        raise MakeError("jobserver FIFO ended while waiting for a token")
      }
      token = Some(byte.unsafe_reinterpret_as_bytes())
    },
  ])
  // Both waiters may acquire before cancellation is observed. Keep the free
  // implicit slot and return the exact extra byte before starting the recipe.
  if implicit_owned && token is Some(value) {
    token = None
    @async.protect_from_cancel(() => self.writer.write(value))
  }
  locked = false
  self.acquiring.release()
  action()
}

///|
fn makeflag_words(value : String) -> Array[String] raise MakeError {
  let words : Array[String] = []
  let word = StringBuilder()
  let mut escaped = false
  for char in value {
    if escaped {
      word.write_char(char)
      escaped = false
    } else if char == '\\' {
      escaped = true
    } else if char is (' ' | '\t' | '\n') {
      if !word.is_empty() {
        words.push(word.to_string())
        word.reset()
      }
    } else {
      word.write_char(char)
    }
  }
  if escaped {
    raise MakeError("MAKEFLAGS ends with an incomplete escape")
  }
  if !word.is_empty() {
    words.push(word.to_string())
  }
  words
}

///|
fn inherited_jobserver(words : Array[String]) -> String? raise MakeError {
  let mut authentication = None
  for token in inherited_make_tokens(words) {
    if token is Authentication(value) {
      authentication = Some(value)
    }
  }
  authentication
}

///|
fn escape_makeflag(value : String) -> String {
  let result = StringBuilder()
  for char in value {
    if char is ('\\' | ' ' | '\t' | '\n') {
      result.write_char('\\')
    }
    result.write_char(char)
  }
  result.to_string()
}

///|
priv enum MakeFlagToken {
  Option(String)
  Assignment(String, (String, String, String))
  Authentication(String)
}

///|
fn inherited_make_tokens(
  words : Array[String],
) -> Array[MakeFlagToken] raise MakeError {
  let result : Array[MakeFlagToken] = []
  let mut assignments = false
  let mut index = 0
  while index < words.length() {
    let word = words[index]
    if word == "--" {
      assignments = true
    } else if assignments || (word.contains("=") && !word.has_prefix("--")) {
      guard parse_assignment(word) is Some(assignment) else {
        raise MakeError("invalid inherited variable assignment")
      }
      result.push(Assignment(word, assignment))
    } else if word.has_prefix("--jobserver-auth=") {
      result.push(Authentication(word[17:].to_owned()))
    } else if word == "--jobserver-auth" {
      index += 1
      guard words.get(index) is Some(value) else {
        raise MakeError("--jobserver-auth requires a value")
      }
      result.push(Authentication(value))
    } else if word == "--no-print-directory" ||
      word == "--print-directory" ||
      word == "--no-builtin-rules" ||
      word == "--no-builtin-variables" {
      ()
    } else if word == "--jobs" &&
      words.get(index + 1) is Some(value) &&
      positive_job_count(value) {
      result.push(Option("-j" + value))
      index += 1
    } else if word.has_prefix("--") {
      result.push(Option(word))
    } else if word != "" {
      let flags = if word.has_prefix("-") { word[1:].to_owned() } else { word }
      let chars = flags.iter().collect()
      let mut cursor = 0
      while cursor < chars.length() {
        let char = chars[cursor]
        if char == 'j' {
          let number = String::from_array(chars[cursor + 1:])
          if number != "" {
            result.push(Option("-j" + number))
          } else if words.get(index + 1) is Some(value) &&
            positive_job_count(value) {
            result.push(Option("-j" + value))
            index += 1
          } else {
            result.push(Option("-j"))
          }
          break
        } else if char is ('k' | 's' | 'n' | 'B') {
          result.push(Option("-" + char.to_string()))
        } else if char is ('w' | 'r' | 'R') {
          ()
        } else {
          raise MakeError("unsupported inherited make flag '\{char}'")
        }
        cursor += 1
      }
    }
    index += 1
  }
  result
}

///|
fn inherited_make_arguments(
  words : Array[String],
  include_assignments~ : Bool = true,
) -> Array[String] raise MakeError {
  let result : Array[String] = []
  for token in inherited_make_tokens(words) {
    match token {
      Option(value) => result.push(value)
      Assignment(value, _) => if include_assignments { result.push(value) }
      Authentication(_) => ()
    }
  }
  result
}

///|
fn inherited_make_assignments(
  words : Array[String],
) -> Array[(String, String, String)] raise MakeError {
  let result : Array[(String, String, String)] = []
  for token in inherited_make_tokens(words) {
    if token is Assignment(_, assignment) {
      result.push(assignment)
    }
  }
  result
}
